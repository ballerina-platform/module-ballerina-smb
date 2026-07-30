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

import io.ballerina.compiler.api.SemanticModel;
import io.ballerina.compiler.api.symbols.TypeDescKind;
import io.ballerina.compiler.api.symbols.TypeReferenceTypeSymbol;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.syntax.tree.FunctionDefinitionNode;
import io.ballerina.compiler.syntax.tree.ParameterNode;
import io.ballerina.compiler.syntax.tree.SeparatedNodeList;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;

import java.util.Optional;

import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_ON_ERROR_FIRST_PARAMETER;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.ON_ERROR_MUST_BE_REMOTE;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.TOO_MANY_PARAMETERS_ON_ERROR;
import static io.ballerina.lib.smb.plugin.PluginUtils.reportErrorDiagnostic;

/**
 * Validates the onError remote function of an SMB service.
 *
 * <p>The SMB listener dispatches {@code onError} with the error as its only argument, so unlike the
 * content handlers this method does not accept a trailing {@code smb:Caller} parameter.
 */
public class SmbOnErrorValidator {

    private static final int EXPECTED_PARAM_COUNT = 1;

    private final SyntaxNodeAnalysisContext context;
    private final FunctionDefinitionNode functionDefinitionNode;

    public SmbOnErrorValidator(SyntaxNodeAnalysisContext context, FunctionDefinitionNode functionDefinitionNode) {
        this.context = context;
        this.functionDefinitionNode = functionDefinitionNode;
    }

    public void validate() {
        if (!PluginUtils.isRemoteFunction(context, functionDefinitionNode)) {
            reportErrorDiagnostic(context, ON_ERROR_MUST_BE_REMOTE, functionDefinitionNode.location());
            return;
        }

        SeparatedNodeList<ParameterNode> parameters = functionDefinitionNode.functionSignature().parameters();
        if (parameters.isEmpty()) {
            reportErrorDiagnostic(context, INVALID_ON_ERROR_FIRST_PARAMETER, functionDefinitionNode.location());
            return;
        }

        if (parameters.size() > EXPECTED_PARAM_COUNT) {
            reportErrorDiagnostic(context, TOO_MANY_PARAMETERS_ON_ERROR, functionDefinitionNode.location());
            return;
        }

        validateErrorParameter(parameters.get(0));
        PluginUtils.validateReturnTypeErrorOrNil(functionDefinitionNode, context);
    }

    private void validateErrorParameter(ParameterNode parameterNode) {
        Optional<TypeSymbol> paramType = PluginUtils.getParameterTypeSymbol(parameterNode, context);
        if (paramType.isEmpty()) {
            reportErrorDiagnostic(context, INVALID_ON_ERROR_FIRST_PARAMETER, parameterNode.location());
            return;
        }

        SemanticModel semanticModel = context.semanticModel();
        TypeSymbol normalizedParamType = unwrapTypeReference(paramType.get());
        if (!normalizedParamType.subtypeOf(semanticModel.types().ERROR)) {
            reportErrorDiagnostic(context, INVALID_ON_ERROR_FIRST_PARAMETER, parameterNode.location());
        }
    }

    private TypeSymbol unwrapTypeReference(TypeSymbol typeSymbol) {
        if (typeSymbol.typeKind() == TypeDescKind.TYPE_REFERENCE &&
                typeSymbol instanceof TypeReferenceTypeSymbol typeReferenceTypeSymbol) {
            return typeReferenceTypeSymbol.typeDescriptor();
        }
        return typeSymbol;
    }
}
