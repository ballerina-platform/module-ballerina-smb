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

import io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors;
import io.ballerina.projects.DiagnosticResult;
import io.ballerina.projects.Package;
import io.ballerina.projects.ProjectEnvironmentBuilder;
import io.ballerina.projects.directory.BuildProject;
import io.ballerina.projects.environment.Environment;
import io.ballerina.projects.environment.EnvironmentBuilder;
import io.ballerina.tools.diagnostics.Diagnostic;
import org.testng.Assert;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.List;

/**
 * Utilities for the SMB compiler plugin tests.
 */
public final class CompilerPluginTestUtils {

    private CompilerPluginTestUtils() {}

    public static final Path RESOURCE_DIRECTORY = Paths.get("src", "test", "resources").toAbsolutePath();
    public static final Path DISTRIBUTION_PATH = Paths.get("../", "target", "ballerina-runtime").toAbsolutePath();
    public static final String BALLERINA_SOURCES = "ballerina_sources";

    public static ProjectEnvironmentBuilder getEnvironmentBuilder() {
        Environment environment = EnvironmentBuilder.getBuilder().setBallerinaHome(DISTRIBUTION_PATH).build();
        return ProjectEnvironmentBuilder.getBuilder(environment);
    }

    public static Package loadPackage(String path) {
        Path projectDirPath = RESOURCE_DIRECTORY.resolve(BALLERINA_SOURCES).resolve(path);
        BuildProject project = BuildProject.load(getEnvironmentBuilder(), projectDirPath);
        return project.currentPackage();
    }

    /**
     * Compiles the given test package and returns its compilation errors.
     *
     * @param path the test package directory under {@code ballerina_sources}
     * @return the errors reported for the package
     */
    public static List<Diagnostic> compileAndGetErrors(String path) {
        DiagnosticResult diagnosticResult = loadPackage(path).getCompilation().diagnosticResult();
        return List.copyOf(diagnosticResult.errors());
    }

    /**
     * Asserts that compiling the given test package reports no errors.
     *
     * @param path the test package directory under {@code ballerina_sources}
     */
    public static void assertNoErrors(String path) {
        List<Diagnostic> errors = compileAndGetErrors(path);
        Assert.assertEquals(errors.size(), 0, "Unexpected errors for '" + path + "': " + errors);
    }

    /**
     * Asserts that compiling the given test package reports exactly the expected set of errors.
     * The comparison ignores the order in which the diagnostics are reported.
     *
     * @param path the test package directory under {@code ballerina_sources}
     * @param expectedErrors the expected errors
     */
    public static void assertErrors(String path, CompilationErrors... expectedErrors) {
        List<Diagnostic> errors = compileAndGetErrors(path);
        List<String> actualCodes = errors.stream()
                .map(diagnostic -> diagnostic.diagnosticInfo().code())
                .sorted()
                .toList();
        List<String> expectedCodes = Arrays.stream(expectedErrors)
                .map(CompilationErrors::getErrorCode)
                .sorted()
                .toList();
        Assert.assertEquals(actualCodes, expectedCodes, "Unexpected diagnostics for '" + path + "': " + errors);
    }

    public static void assertDiagnosticCode(Diagnostic diagnostic, CompilationErrors error) {
        Assert.assertEquals(diagnostic.diagnosticInfo().code(), error.getErrorCode(),
                "Unexpected diagnostic: " + diagnostic);
    }

    public static void assertDiagnostic(Diagnostic diagnostic, CompilationErrors error) {
        Assert.assertEquals(diagnostic.diagnosticInfo().code(), error.getErrorCode());
        Assert.assertEquals(diagnostic.diagnosticInfo().messageFormat(), error.getError());
    }

    public static void assertDiagnostic(Diagnostic diagnostic, CompilationErrors error, String expectedMessage) {
        Assert.assertEquals(diagnostic.diagnosticInfo().code(), error.getErrorCode());
        Assert.assertEquals(diagnostic.message(), expectedMessage);
    }
}
