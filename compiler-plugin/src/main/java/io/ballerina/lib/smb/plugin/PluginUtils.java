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
import io.ballerina.compiler.api.symbols.MethodSymbol;
import io.ballerina.compiler.api.symbols.ModuleSymbol;
import io.ballerina.compiler.api.symbols.ParameterSymbol;
import io.ballerina.compiler.api.symbols.Qualifier;
import io.ballerina.compiler.api.symbols.Symbol;
import io.ballerina.compiler.api.symbols.TypeDescKind;
import io.ballerina.compiler.api.symbols.TypeSymbol;
import io.ballerina.compiler.api.symbols.UnionTypeSymbol;
import io.ballerina.compiler.syntax.tree.FunctionDefinitionNode;
import io.ballerina.compiler.syntax.tree.ParameterNode;
import io.ballerina.compiler.syntax.tree.RequiredParameterNode;
import io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;
import io.ballerina.tools.diagnostics.Diagnostic;
import io.ballerina.tools.diagnostics.DiagnosticFactory;
import io.ballerina.tools.diagnostics.DiagnosticInfo;
import io.ballerina.tools.diagnostics.DiagnosticSeverity;
import io.ballerina.tools.diagnostics.Location;

import java.util.Optional;

import static io.ballerina.compiler.syntax.tree.SyntaxKind.QUALIFIED_NAME_REFERENCE;
import static io.ballerina.lib.smb.plugin.PluginConstants.CALLER;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_RETURN_TYPE_ERROR_OR_NIL;
import static io.ballerina.lib.smb.plugin.PluginConstants.FILE_INFO;

/**
 * Util class for the SMB compiler plugin.
 */
public final class PluginUtils {

    private PluginUtils() {}

    public static void reportErrorDiagnostic(SyntaxNodeAnalysisContext context, CompilationErrors error,
                                             Location location) {
        context.reportDiagnostic(getDiagnostic(error, DiagnosticSeverity.ERROR, location));
    }

    public static void reportErrorDiagnostic(SyntaxNodeAnalysisContext context, CompilationErrors error,
                                             Location location, Object... args) {
        context.reportDiagnostic(getDiagnostic(error, DiagnosticSeverity.ERROR, location, args));
    }

    public static Diagnostic getDiagnostic(CompilationErrors error, DiagnosticSeverity severity, Location location) {
        DiagnosticInfo diagnosticInfo = new DiagnosticInfo(error.getErrorCode(),
                escapeMessageFormatChars(error.getError()), severity);
        return DiagnosticFactory.createDiagnostic(diagnosticInfo, location);
    }

    public static Diagnostic getDiagnostic(CompilationErrors error, DiagnosticSeverity severity, Location location,
                                           Object... args) {
        String errorMessage = String.format(error.getError(), args);
        DiagnosticInfo diagnosticInfo = new DiagnosticInfo(error.getErrorCode(),
                escapeMessageFormatChars(errorMessage), severity);
        return DiagnosticFactory.createDiagnostic(diagnosticInfo, location);
    }

    /**
     * Escapes a diagnostic message so that it survives rendering intact.
     *
     * <p>{@code Diagnostic.message()} runs the stored message through {@code MessageFormat}, which gives
     * two characters special meaning. A brace is read as an argument reference, and an unparseable one
     * throws — aborting the compilation rather than merely garbling the text. A single quote opens a
     * literal-quoting section and is itself dropped.
     *
     * <p>Both can legitimately appear in an interpolated type signature: an inline
     * {@code record {| ... |}} parameter carries braces, and a Ballerina quoted identifier such as
     * {@code 'limit} carries an apostrophe.
     *
     * <p>Order matters. Apostrophes are doubled first, since that is how {@code MessageFormat} spells a
     * literal quote; the braces are only then wrapped in quoting of our own. Doing it the other way round
     * would double the quotes this method just added and corrupt the escaping.
     *
     * @param message the formatted diagnostic message
     * @return the message with apostrophes and curly braces escaped
     */
    private static String escapeMessageFormatChars(String message) {
        return message
                .replace("'", "''")
                .replace("{", "'{'")
                .replace("}", "'}'");
    }

    public static boolean validateModuleId(ModuleSymbol moduleSymbol) {
        if (moduleSymbol == null) {
            return false;
        }
        return PluginConstants.PACKAGE_PREFIX.equals(moduleSymbol.id().moduleName()) &&
                PluginConstants.PACKAGE_ORG.equals(moduleSymbol.id().orgName());
    }

    public static boolean isRemoteFunction(SyntaxNodeAnalysisContext context,
                                           FunctionDefinitionNode functionDefinitionNode) {
        MethodSymbol methodSymbol = getMethodSymbol(context, functionDefinitionNode);
        return methodSymbol != null && methodSymbol.qualifiers().contains(Qualifier.REMOTE);
    }

    public static MethodSymbol getMethodSymbol(SyntaxNodeAnalysisContext context,
                                               FunctionDefinitionNode functionDefinitionNode) {
        Optional<Symbol> symbol = context.semanticModel().symbol(functionDefinitionNode);
        if (symbol.isPresent() && symbol.get() instanceof MethodSymbol methodSymbol) {
            return methodSymbol;
        }
        return null;
    }

    /**
     * Validates that a parameter is of type smb:FileInfo.
     *
     * @param parameterNode the parameter node to validate
     * @param context the syntax node analysis context
     * @return true if the parameter is smb:FileInfo, false otherwise
     */
    public static boolean validateFileInfoParameter(ParameterNode parameterNode,
                                                    SyntaxNodeAnalysisContext context) {
        return validateQualifiedSmbParameter(parameterNode, context, FILE_INFO);
    }

    /**
     * Validates that a parameter is of type smb:Caller.
     *
     * @param parameterNode the parameter node to validate
     * @param context the syntax node analysis context
     * @return true if the parameter is smb:Caller, false otherwise
     */
    public static boolean validateCallerParameter(ParameterNode parameterNode,
                                                  SyntaxNodeAnalysisContext context) {
        return validateQualifiedSmbParameter(parameterNode, context, CALLER);
    }

    private static boolean validateQualifiedSmbParameter(ParameterNode parameterNode,
                                                         SyntaxNodeAnalysisContext context,
                                                         String expectedTypeName) {
        if (!(parameterNode instanceof RequiredParameterNode requiredParameterNode)) {
            return false;
        }
        if (requiredParameterNode.typeName().kind() != QUALIFIED_NAME_REFERENCE) {
            return false;
        }
        Optional<TypeSymbol> typeSymbol = getParameterTypeSymbol(parameterNode, context);
        if (typeSymbol.isEmpty()) {
            return false;
        }
        Optional<ModuleSymbol> moduleSymbol = typeSymbol.get().getModule();
        if (moduleSymbol.isEmpty() || !validateModuleId(moduleSymbol.get())) {
            return false;
        }
        return typeSymbol.get().getName().map(expectedTypeName::equals).orElse(false);
    }

    public static Optional<TypeSymbol> getParameterTypeSymbol(ParameterNode parameterNode,
                                                              SyntaxNodeAnalysisContext context) {
        if (!(parameterNode instanceof RequiredParameterNode requiredParameterNode)) {
            return Optional.empty();
        }
        Optional<Symbol> symbol = context.semanticModel().symbol(requiredParameterNode);
        if (symbol.isEmpty() || !(symbol.get() instanceof ParameterSymbol parameterSymbol)) {
            return Optional.empty();
        }
        return Optional.ofNullable(parameterSymbol.typeDescriptor());
    }

    /**
     * Returns the parameter's type as it should appear in a diagnostic.
     *
     * <p>Types declared by this module are rendered as {@code smb:FileInfo} rather than using
     * {@link TypeSymbol#signature()}, which would emit {@code ballerina/smb:1.1.0:FileInfo} and leak the
     * package version into the message on every release.
     *
     * @param parameterNode the parameter whose type is being reported
     * @param context the syntax node analysis context
     * @return a displayable type name, or {@code unknown} if the type cannot be resolved
     */
    public static String getParameterTypeSignature(ParameterNode parameterNode,
                                                   SyntaxNodeAnalysisContext context) {
        return getParameterTypeSymbol(parameterNode, context)
                .map(PluginUtils::getDisplayTypeName)
                .orElse("unknown");
    }

    public static String getDisplayTypeName(TypeSymbol typeSymbol) {
        boolean isSmbType = typeSymbol.getModule().map(PluginUtils::validateModuleId).orElse(false);
        if (isSmbType) {
            return typeSymbol.getName()
                    .map(name -> PluginConstants.PACKAGE_PREFIX + ":" + name)
                    .orElseGet(typeSymbol::signature);
        }
        return typeSymbol.signature();
    }

    /**
     * Validates that the return type of a handler is a subtype of {@code error?}.
     * Reports a diagnostic error if the return type is invalid.
     *
     * @param functionDefinitionNode the function definition node to validate
     * @param context the syntax node analysis context
     */
    public static void validateReturnTypeErrorOrNil(FunctionDefinitionNode functionDefinitionNode,
                                                    SyntaxNodeAnalysisContext context) {
        MethodSymbol methodSymbol = getMethodSymbol(context, functionDefinitionNode);
        if (methodSymbol == null) {
            return;
        }
        Optional<TypeSymbol> returnTypeDesc = methodSymbol.typeDescriptor().returnTypeDescriptor();
        if (returnTypeDesc.isEmpty()) {
            return;
        }
        SemanticModel semanticModel = context.semanticModel();
        if (!isErrorOrNil(returnTypeDesc.get(), semanticModel.types().ERROR)) {
            context.reportDiagnostic(getDiagnostic(INVALID_RETURN_TYPE_ERROR_OR_NIL, DiagnosticSeverity.ERROR,
                    functionDefinitionNode.functionSignature().location()));
        }
    }

    private static boolean isErrorOrNil(TypeSymbol typeSymbol, TypeSymbol errorType) {
        if (typeSymbol.typeKind() == TypeDescKind.NIL) {
            return true;
        }
        if (typeSymbol.typeKind() == TypeDescKind.UNION && typeSymbol instanceof UnionTypeSymbol unionTypeSymbol) {
            for (TypeSymbol memberType : unionTypeSymbol.memberTypeDescriptors()) {
                if (!isErrorOrNil(memberType, errorType)) {
                    return false;
                }
            }
            return true;
        }
        return typeSymbol.subtypeOf(errorType);
    }
}
