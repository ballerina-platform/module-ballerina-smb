/*
 * Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package io.ballerina.lib.smb.plugin;

import io.ballerina.compiler.api.symbols.ArrayTypeSymbol;
import io.ballerina.compiler.api.symbols.StreamTypeSymbol;
import io.ballerina.compiler.api.symbols.TypeDescKind;
import io.ballerina.compiler.api.symbols.TypeReferenceTypeSymbol;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.syntax.tree.FunctionDefinitionNode;
import io.ballerina.compiler.syntax.tree.ParameterNode;
import io.ballerina.compiler.syntax.tree.SeparatedNodeList;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;

import java.util.Optional;

import static io.ballerina.compiler.api.symbols.TypeDescKind.ARRAY;
import static io.ballerina.compiler.api.symbols.TypeDescKind.BYTE;
import static io.ballerina.compiler.api.symbols.TypeDescKind.JSON;
import static io.ballerina.compiler.api.symbols.TypeDescKind.RECORD;
import static io.ballerina.compiler.api.symbols.TypeDescKind.STREAM;
import static io.ballerina.compiler.api.symbols.TypeDescKind.STRING;
import static io.ballerina.compiler.api.symbols.TypeDescKind.TYPE_REFERENCE;
import static io.ballerina.compiler.api.symbols.TypeDescKind.XML;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.CONTENT_METHOD_MUST_BE_REMOTE;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.DUPLICATE_OPTIONAL_PARAMETER;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_CONTENT_PARAMETER_TYPE;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_OPTIONAL_PARAMETER;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.MANDATORY_PARAMETER_NOT_FOUND;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.TOO_MANY_PARAMETERS;
import static io.ballerina.lib.smb.plugin.PluginConstants.ON_FILE_CSV_FUNC;
import static io.ballerina.lib.smb.plugin.PluginConstants.ON_FILE_FUNC;
import static io.ballerina.lib.smb.plugin.PluginConstants.ON_FILE_JSON_FUNC;
import static io.ballerina.lib.smb.plugin.PluginConstants.ON_FILE_TEXT_FUNC;
import static io.ballerina.lib.smb.plugin.PluginConstants.ON_FILE_XML_FUNC;
import static io.ballerina.lib.smb.plugin.PluginUtils.isRemoteFunction;
import static io.ballerina.lib.smb.plugin.PluginUtils.reportErrorDiagnostic;

/**
 * Validates the format-specific content handlers of an SMB service.
 */
public class SmbContentFunctionValidator {

    private static final int MAX_PARAM_COUNT = 3;

    private final SyntaxNodeAnalysisContext context;
    private final FunctionDefinitionNode funcDefinitionNode;
    private final String contentMethodName;

    public SmbContentFunctionValidator(SyntaxNodeAnalysisContext context,
                                       FunctionDefinitionNode funcDefinitionNode,
                                       String contentMethodName) {
        this.context = context;
        this.funcDefinitionNode = funcDefinitionNode;
        this.contentMethodName = contentMethodName;
    }

    public void validate() {
        if (!isRemoteFunction(context, funcDefinitionNode)) {
            reportErrorDiagnostic(context, CONTENT_METHOD_MUST_BE_REMOTE,
                    funcDefinitionNode.location(), contentMethodName);
        }
        validateContentFunctionParameters(funcDefinitionNode.functionSignature().parameters());
        PluginUtils.validateReturnTypeErrorOrNil(funcDefinitionNode, context);
    }

    private void validateContentFunctionParameters(SeparatedNodeList<ParameterNode> parameters) {
        if (parameters.isEmpty()) {
            reportErrorDiagnostic(context, MANDATORY_PARAMETER_NOT_FOUND, funcDefinitionNode.location(),
                    contentMethodName, getExpectedContentType());
            return;
        }

        if (parameters.size() > MAX_PARAM_COUNT) {
            reportErrorDiagnostic(context, TOO_MANY_PARAMETERS, funcDefinitionNode.location(), contentMethodName);
            return;
        }

        ParameterNode firstParameter = parameters.get(0);
        if (!validateContentParameter(firstParameter)) {
            reportErrorDiagnostic(context, INVALID_CONTENT_PARAMETER_TYPE, firstParameter.location(),
                    contentMethodName, getExpectedContentType(),
                    PluginUtils.getParameterTypeSignature(firstParameter, context));
        }

        // The listener resolves the optional parameters by type rather than by position, so
        // `smb:FileInfo` and `smb:Caller` may appear in either order, but neither may repeat.
        boolean fileInfoSeen = false;
        boolean callerSeen = false;
        for (int i = 1; i < parameters.size(); i++) {
            ParameterNode parameter = parameters.get(i);
            if (PluginUtils.validateFileInfoParameter(parameter, context)) {
                if (fileInfoSeen) {
                    reportErrorDiagnostic(context, DUPLICATE_OPTIONAL_PARAMETER, parameter.location(),
                            contentMethodName, PluginConstants.FILE_INFO);
                }
                fileInfoSeen = true;
            } else if (PluginUtils.validateCallerParameter(parameter, context)) {
                if (callerSeen) {
                    reportErrorDiagnostic(context, DUPLICATE_OPTIONAL_PARAMETER, parameter.location(),
                            contentMethodName, PluginConstants.CALLER);
                }
                callerSeen = true;
            } else {
                reportErrorDiagnostic(context, INVALID_OPTIONAL_PARAMETER, parameter.location(), contentMethodName);
            }
        }
    }

    private boolean validateContentParameter(ParameterNode parameterNode) {
        Optional<TypeSymbol> typeSymbolOpt = PluginUtils.getParameterTypeSymbol(parameterNode, context);
        if (typeSymbolOpt.isEmpty()) {
            return false;
        }

        TypeSymbol typeSymbol = typeSymbolOpt.get();
        TypeDescKind typeKind = typeSymbol.typeKind();

        return switch (contentMethodName) {
            case ON_FILE_FUNC -> validateOnFileContentType(typeKind, typeSymbol);
            case ON_FILE_TEXT_FUNC -> typeKind == STRING;
            case ON_FILE_JSON_FUNC -> typeKind == JSON || typeKind == RECORD || isRecordTypeReference(typeSymbol);
            case ON_FILE_XML_FUNC -> typeKind == XML || typeKind == RECORD || isRecordTypeReference(typeSymbol);
            case ON_FILE_CSV_FUNC -> validateOnFileCsvContentType(typeKind, typeSymbol);
            default -> false;
        };
    }

    private boolean validateOnFileContentType(TypeDescKind typeKind, TypeSymbol typeSymbol) {
        // onFile accepts byte[] or stream<byte[], error?>
        if (typeKind == ARRAY) {
            return ((ArrayTypeSymbol) typeSymbol).memberTypeDescriptor().typeKind() == BYTE;
        }
        if (typeKind == STREAM) {
            TypeSymbol itemType = ((StreamTypeSymbol) typeSymbol).typeParameter();
            return itemType instanceof ArrayTypeSymbol arrayType &&
                    arrayType.memberTypeDescriptor().typeKind() == BYTE;
        }
        return false;
    }

    private boolean validateOnFileCsvContentType(TypeDescKind typeKind, TypeSymbol typeSymbol) {
        if (typeKind == ARRAY) {
            // Array variant: string[][] or record{}[]
            ArrayTypeSymbol arrayTypeSymbol = (ArrayTypeSymbol) typeSymbol;
            return isStringArrayOfArray(arrayTypeSymbol) || isRecordArray(arrayTypeSymbol);
        }
        if (typeKind == STREAM) {
            // Stream variant: stream<string[], error?> or stream<record{}, error?>
            StreamTypeSymbol streamTypeSymbol = (StreamTypeSymbol) typeSymbol;
            return isStringArrayStream(streamTypeSymbol) || isRecordStream(streamTypeSymbol);
        }
        return false;
    }

    private boolean isRecordStream(StreamTypeSymbol streamType) {
        TypeSymbol itemType = streamType.typeParameter();
        return itemType.typeKind() == RECORD || isRecordTypeReference(itemType);
    }

    private boolean isStringArrayStream(StreamTypeSymbol streamType) {
        TypeSymbol itemType = streamType.typeParameter();
        return itemType instanceof ArrayTypeSymbol arrayType &&
                arrayType.memberTypeDescriptor().typeKind() == STRING;
    }

    private boolean isStringArrayOfArray(ArrayTypeSymbol outerArray) {
        return outerArray.memberTypeDescriptor() instanceof ArrayTypeSymbol innerArray &&
                innerArray.memberTypeDescriptor().typeKind() == STRING;
    }

    private boolean isRecordArray(ArrayTypeSymbol arrayType) {
        TypeSymbol memberType = arrayType.memberTypeDescriptor();
        return memberType.typeKind() == RECORD || isRecordTypeReference(memberType);
    }

    private boolean isRecordTypeReference(TypeSymbol typeSymbol) {
        if (typeSymbol.typeKind() != TYPE_REFERENCE) {
            return false;
        }
        TypeSymbol referredType = ((TypeReferenceTypeSymbol) typeSymbol).typeDescriptor();
        return referredType != null && referredType.typeKind() == RECORD;
    }

    private String getExpectedContentType() {
        return switch (contentMethodName) {
            case ON_FILE_FUNC -> "byte[] or stream<byte[], error?>";
            case ON_FILE_TEXT_FUNC -> "string";
            case ON_FILE_JSON_FUNC -> "json or record{}";
            case ON_FILE_XML_FUNC -> "xml or record{}";
            case ON_FILE_CSV_FUNC ->
                    "string[][], record{}[], stream<string[], error?>, or stream<record{}, error?>";
            default -> "unknown";
        };
    }
}
