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

import io.ballerina.compiler.api.symbols.TypeDescKind;
import io.ballerina.compiler.syntax.tree.FunctionDefinitionNode;
import io.ballerina.compiler.syntax.tree.ParameterNode;
import io.ballerina.compiler.syntax.tree.SeparatedNodeList;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;

import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_ON_FILE_DELETE_CALLER_PARAMETER;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_ON_FILE_DELETE_PARAMETER;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.MANDATORY_PARAMETER_NOT_FOUND;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.ON_FILE_DELETE_MUST_BE_REMOTE;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.TOO_MANY_PARAMETERS_ON_FILE_DELETE;
import static io.ballerina.lib.smb.plugin.PluginConstants.ON_FILE_DELETE_FUNC;
import static io.ballerina.lib.smb.plugin.PluginUtils.getParameterTypeSymbol;
import static io.ballerina.lib.smb.plugin.PluginUtils.isRemoteFunction;
import static io.ballerina.lib.smb.plugin.PluginUtils.reportErrorDiagnostic;

/**
 * Validates the onFileDelete remote function of an SMB service.
 */
public class SmbFileDeleteValidator {

    private static final int MAX_PARAM_COUNT = 2;

    private final SyntaxNodeAnalysisContext context;
    private final FunctionDefinitionNode functionDefinitionNode;

    public SmbFileDeleteValidator(SyntaxNodeAnalysisContext context,
                                  FunctionDefinitionNode functionDefinitionNode) {
        this.context = context;
        this.functionDefinitionNode = functionDefinitionNode;
    }

    public void validate() {
        if (!isRemoteFunction(context, functionDefinitionNode)) {
            reportErrorDiagnostic(context, ON_FILE_DELETE_MUST_BE_REMOTE, functionDefinitionNode.location());
        }
        validateParameters(functionDefinitionNode.functionSignature().parameters());
        PluginUtils.validateReturnTypeErrorOrNil(functionDefinitionNode, context);
    }

    private void validateParameters(SeparatedNodeList<ParameterNode> parameters) {
        if (parameters.isEmpty()) {
            reportErrorDiagnostic(context, MANDATORY_PARAMETER_NOT_FOUND, functionDefinitionNode.location(),
                    ON_FILE_DELETE_FUNC, "string");
            return;
        }

        if (parameters.size() > MAX_PARAM_COUNT) {
            reportErrorDiagnostic(context, TOO_MANY_PARAMETERS_ON_FILE_DELETE, functionDefinitionNode.location());
            return;
        }

        ParameterNode firstParameter = parameters.get(0);
        if (!isStringParameter(firstParameter)) {
            reportErrorDiagnostic(context, INVALID_ON_FILE_DELETE_PARAMETER, firstParameter.location());
        }

        if (parameters.size() == MAX_PARAM_COUNT &&
                !PluginUtils.validateCallerParameter(parameters.get(1), context)) {
            reportErrorDiagnostic(context, INVALID_ON_FILE_DELETE_CALLER_PARAMETER, parameters.get(1).location());
        }
    }

    private boolean isStringParameter(ParameterNode parameterNode) {
        return getParameterTypeSymbol(parameterNode, context)
                .map(typeSymbol -> typeSymbol.typeKind() == TypeDescKind.STRING)
                .orElse(false);
    }
}
