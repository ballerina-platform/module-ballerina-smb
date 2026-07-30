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

import org.testng.annotations.Test;

import static io.ballerina.lib.smb.plugin.CompilerPluginTestUtils.assertErrors;
import static io.ballerina.lib.smb.plugin.CompilerPluginTestUtils.assertNoErrors;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.CONTENT_METHOD_MUST_BE_REMOTE;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.DUPLICATE_OPTIONAL_PARAMETER;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_CONTENT_PARAMETER_TYPE;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_OPTIONAL_PARAMETER;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_ON_ERROR_FIRST_PARAMETER;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_ON_ERROR_SECOND_PARAMETER;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_ON_FILE_DELETE_CALLER_PARAMETER;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_ON_FILE_DELETE_PARAMETER;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_REMOTE_FUNCTION;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.INVALID_RETURN_TYPE_ERROR_OR_NIL;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.MANDATORY_PARAMETER_NOT_FOUND;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.NO_VALID_REMOTE_METHOD;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.ON_ERROR_MUST_BE_REMOTE;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.ON_FILE_DELETE_MUST_BE_REMOTE;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.RESOURCE_FUNCTION_NOT_ALLOWED;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.TOO_MANY_PARAMETERS;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.TOO_MANY_PARAMETERS_ON_ERROR;
import static io.ballerina.lib.smb.plugin.PluginConstants.CompilationErrors.TOO_MANY_PARAMETERS_ON_FILE_DELETE;

/**
 * Tests for the SMB package compiler plugin.
 */
public class SmbServiceValidationTest {

    @Test(description = "Every handler with a valid signature")
    public void testValidService1() {
        assertNoErrors("valid_service_1");
    }

    @Test(description = "Stream and record content types, renamed import, isolated service")
    public void testValidService2() {
        assertNoErrors("valid_service_2");
    }

    @Test(description = "Annotations, multiple listeners, service variables and non-handler methods")
    public void testValidService3() {
        assertNoErrors("valid_service_3");
    }

    @Test(description = "onFileDelete as the only handler")
    public void testValidService4() {
        assertNoErrors("valid_service_4");
    }

    @Test(description = "Every handler signature used by the SMB package's own tests and examples")
    public void testValidLibrarySignatures() {
        assertNoErrors("valid_library_signatures");
    }

    @Test(description = "Services on a non-SMB listener are not validated by the SMB plugin")
    public void testNonSmbListenerIsIgnored() {
        assertNoErrors("valid_non_smb_listener");
    }

    @Test(description = "Resource functions are not allowed and a handler is mandatory")
    public void testInvalidService1() {
        assertErrors("invalid_service_1", RESOURCE_FUNCTION_NOT_ALLOWED, NO_VALID_REMOTE_METHOD);
    }

    @Test(description = "Unknown remote method names are rejected")
    public void testInvalidService2() {
        assertErrors("invalid_service_2", INVALID_REMOTE_FUNCTION);
    }

    @Test(description = "onError alone does not satisfy the handler requirement")
    public void testInvalidService3() {
        assertErrors("invalid_service_3", NO_VALID_REMOTE_METHOD);
    }

    @Test(description = "Content handlers must be remote")
    public void testInvalidContentService1() {
        assertErrors("invalid_content_service_1", CONTENT_METHOD_MUST_BE_REMOTE, CONTENT_METHOD_MUST_BE_REMOTE);
    }

    @Test(description = "Content handlers require the content parameter")
    public void testInvalidContentService2() {
        assertErrors("invalid_content_service_2", MANDATORY_PARAMETER_NOT_FOUND, MANDATORY_PARAMETER_NOT_FOUND);
    }

    @Test(description = "Content parameter type must match the handler")
    public void testInvalidContentService3() {
        assertErrors("invalid_content_service_3", INVALID_CONTENT_PARAMETER_TYPE, INVALID_CONTENT_PARAMETER_TYPE,
                INVALID_CONTENT_PARAMETER_TYPE, INVALID_CONTENT_PARAMETER_TYPE, INVALID_CONTENT_PARAMETER_TYPE);
    }

    @Test(description = "Optional parameters must be FileInfo or Caller, and neither may repeat")
    public void testInvalidContentService4() {
        assertErrors("invalid_content_service_4", INVALID_OPTIONAL_PARAMETER, INVALID_OPTIONAL_PARAMETER,
                DUPLICATE_OPTIONAL_PARAMETER);
    }

    @Test(description = "Content handler arity and return type")
    public void testInvalidContentService5() {
        assertErrors("invalid_content_service_5", TOO_MANY_PARAMETERS, INVALID_RETURN_TYPE_ERROR_OR_NIL,
                INVALID_RETURN_TYPE_ERROR_OR_NIL);
    }

    @Test(description = "onFileDelete must be remote")
    public void testInvalidOnFileDelete1() {
        assertErrors("invalid_on_file_delete_1", ON_FILE_DELETE_MUST_BE_REMOTE);
    }

    @Test(description = "onFileDelete takes a single string path, not string[]")
    public void testInvalidOnFileDelete2() {
        assertErrors("invalid_on_file_delete_2", INVALID_ON_FILE_DELETE_PARAMETER);
    }

    @Test(description = "The optional second parameter of onFileDelete must be Caller")
    public void testInvalidOnFileDelete3() {
        assertErrors("invalid_on_file_delete_3", INVALID_ON_FILE_DELETE_CALLER_PARAMETER);
    }

    @Test(description = "onFileDelete accepts at most two parameters")
    public void testInvalidOnFileDelete4() {
        assertErrors("invalid_on_file_delete_4", TOO_MANY_PARAMETERS_ON_FILE_DELETE);
    }

    @Test(description = "onFileDelete requires the deleted path parameter")
    public void testInvalidOnFileDelete5() {
        assertErrors("invalid_on_file_delete_5", MANDATORY_PARAMETER_NOT_FOUND);
    }

    @Test(description = "onError must be remote")
    public void testInvalidOnError1() {
        assertErrors("invalid_on_error_1", ON_ERROR_MUST_BE_REMOTE);
    }

    @Test(description = "The onError parameter must be an error")
    public void testInvalidOnError2() {
        assertErrors("invalid_on_error_2", INVALID_ON_ERROR_FIRST_PARAMETER);
    }

    @Test(description = "The optional second parameter of onError must be Caller")
    public void testInvalidOnError3() {
        assertErrors("invalid_on_error_3", INVALID_ON_ERROR_SECOND_PARAMETER);
    }

    @Test(description = "onError requires the error parameter")
    public void testInvalidOnError4() {
        assertErrors("invalid_on_error_4", INVALID_ON_ERROR_FIRST_PARAMETER);
    }

    @Test(description = "onError accepts at most two parameters")
    public void testInvalidOnError5() {
        assertErrors("invalid_on_error_5", TOO_MANY_PARAMETERS_ON_ERROR);
    }
}
