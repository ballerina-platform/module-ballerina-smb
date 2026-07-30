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

import io.ballerina.compiler.api.symbols.MethodSymbol;
import io.ballerina.compiler.syntax.tree.FunctionDefinitionNode;
import io.ballerina.compiler.syntax.tree.Node;
import io.ballerina.compiler.syntax.tree.NodeList;
import io.ballerina.compiler.syntax.tree.ServiceDeclarationNode;
import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;
import io.ballerina.tools.diagnostics.DiagnosticSeverity;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static io.ballerina.compiler.syntax.tree.SyntaxKind.RESOURCE_ACCESSOR_DEFINITION;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_REMOTE_FUNCTION;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.NO_VALID_REMOTE_METHOD;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.RESOURCE_FUNCTION_NOT_ALLOWED;
import static io.ballerina.lib.smb.plugin.PluginConstants.ON_ERROR_FUNC;
import static io.ballerina.lib.smb.plugin.PluginConstants.ON_FILE_DELETE_FUNC;
import static io.ballerina.lib.smb.plugin.PluginUtils.getDiagnostic;
import static io.ballerina.lib.smb.plugin.PluginUtils.isRemoteFunction;

/**
 * SMB service compilation validator.
 */
public class SmbServiceValidator {

    public void validate(SyntaxNodeAnalysisContext context) {
        ServiceDeclarationNode serviceDeclarationNode = (ServiceDeclarationNode) context.node();
        NodeList<Node> memberNodes = serviceDeclarationNode.members();

        FunctionDefinitionNode onFileDelete = null;
        FunctionDefinitionNode onError = null;
        List<FunctionDefinitionNode> contentMethods = new ArrayList<>();
        List<String> contentMethodNames = new ArrayList<>();

        for (Node node : memberNodes) {
            if (node.kind() == RESOURCE_ACCESSOR_DEFINITION) {
                context.reportDiagnostic(getDiagnostic(RESOURCE_FUNCTION_NOT_ALLOWED,
                        DiagnosticSeverity.ERROR, node.location()));
                continue;
            }

            if (node.kind() != SyntaxKind.OBJECT_METHOD_DEFINITION) {
                continue;
            }

            FunctionDefinitionNode functionDefinitionNode = (FunctionDefinitionNode) node;
            MethodSymbol methodSymbol = PluginUtils.getMethodSymbol(context, functionDefinitionNode);
            if (methodSymbol == null) {
                continue;
            }
            Optional<String> functionName = methodSymbol.getName();
            if (functionName.isEmpty()) {
                continue;
            }

            String funcName = functionName.get();
            if (PluginConstants.ALL_FORMAT_HANDLERS.contains(funcName)) {
                contentMethods.add(functionDefinitionNode);
                contentMethodNames.add(funcName);
            } else if (ON_FILE_DELETE_FUNC.equals(funcName)) {
                onFileDelete = functionDefinitionNode;
            } else if (ON_ERROR_FUNC.equals(funcName)) {
                onError = functionDefinitionNode;
            } else if (isRemoteFunction(context, functionDefinitionNode)) {
                context.reportDiagnostic(getDiagnostic(INVALID_REMOTE_FUNCTION,
                        DiagnosticSeverity.ERROR, functionDefinitionNode.location()));
            }
        }

        if (contentMethods.isEmpty() && onFileDelete == null) {
            context.reportDiagnostic(getDiagnostic(NO_VALID_REMOTE_METHOD, DiagnosticSeverity.ERROR,
                    serviceDeclarationNode.location()));
            return;
        }

        for (int i = 0; i < contentMethods.size(); i++) {
            new SmbContentFunctionValidator(context, contentMethods.get(i), contentMethodNames.get(i)).validate();
        }

        if (onFileDelete != null) {
            new SmbFileDeleteValidator(context, onFileDelete).validate();
        }

        if (onError != null) {
            new SmbOnErrorValidator(context, onError).validate();
        }
    }
}
