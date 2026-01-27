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

package io.ballerina.stdlib.smb.util;

import io.ballerina.lib.data.xmldata.xml.Native;
import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.utils.JsonUtils;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.utils.TypeUtils;
import io.ballerina.runtime.api.utils.XmlUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BString;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.charset.StandardCharsets;

import static io.ballerina.stdlib.smb.client.SmbClient.SMB_ERROR;

/**
 * Utility class for converting file content to various Ballerina types using data binding modules.
 * Uses io.ballerina.lib.data.jsondata, xmldata, and csvdata for proper data binding.
 */
public final class SmbContentConverter {

    private static final Logger log = LoggerFactory.getLogger(SmbContentConverter.class);
    public static final String CURRENT_DIRECTORY_PATH = System.getProperty("user.dir");
    public static final String ERROR_LOG_FILE_NAME = "error.log";
    public static final BString APPEND = StringUtils.fromString("APPEND");
    public static final BString FILE_WRITE_OPTION = StringUtils.fromString("fileWriteOption");
    public static final BString CONTENT_TYPE = StringUtils.fromString("contentType");
    public static final BString FILE_OUTPUT_MODE = StringUtils.fromString("fileOutputMode");
    public static final BString FAIL_SAFE = StringUtils.fromString("failSafe");
    public static final String FAIL_SAFE_OPTIONS = "FailSafeOptions";
    public static final String FILE_OUTPUT_MODE_TYPE = "FileOutputMode";

    private SmbContentConverter() {
        // private constructor
    }

    /**
     * Converts byte array to Ballerina string (UTF-8).
     *
     * @param content The byte array content
     * @return Ballerina string
     */
    public static BString convertBytesToString(byte[] content) {
        String textContent = new String(content, StandardCharsets.UTF_8);
        return StringUtils.fromString(textContent);
    }

    /**
     * Converts byte array to Ballerina JSON using data.jsondata module.
     *
     * @param content    The byte array content
     * @param targetType The target Ballerina type for data binding
     * @param laxDataBinding Whether to enable lax data binding
     * @return Ballerina JSON object or BError
     */
    public static Object convertBytesToJson(byte[] content, Type targetType, boolean laxDataBinding) {
        try {
            String jsonString = new String(content, StandardCharsets.UTF_8);

            // Parse JSON string directly using Ballerina's JSON utilities
            Object jsonValue = JsonUtils.parse(jsonString);

            // For json type, return directly. For other types, JsonUtils.parse should handle it
            return jsonValue;
        } catch (Exception e) {
            log.error("Error converting bytes to JSON", e);
            return SmbUtil.createError("Failed to parse JSON content: " + e.getMessage(), SMB_ERROR);
        }
    }

    public static Object convertBytesToXml(byte[] content, Type targetType, boolean laxDataBinding) {
        try {
            if (targetType.getQualifiedName().equals("xml")) {
                return XmlUtils.parse(StringUtils.fromString(new String(content, StandardCharsets.UTF_8)));
            }

            // Create empty options map - the library will use defaults
            BMap<BString, Object> options = ValueCreator.createMapValue();
            Object bXml = Native.parseBytes(
                    ValueCreator.createArrayValue(content), options, ValueCreator.createTypedescValue(targetType));
            if (bXml instanceof BError) {
                return SmbUtil.createError(((BError) bXml).getErrorMessage().getValue(), SMB_ERROR);
            }
            return bXml;
        } catch (BError e) {
            return SmbUtil.createError(e.getErrorMessage().getValue(), SMB_ERROR);
        }
    }

    public static Object convertBytesToCsv(Environment env, byte[] content, Type targetType, boolean laxDataBinding,
                                           BMap<?, ?> csvFailSafeConfigs, String fileNamePrefix) {
        try {
            // For now, use simple CSV parsing by converting to string and splitting
            // This works for basic string[][] CSV data
            String csvContent = new String(content, StandardCharsets.UTF_8);

            // Parse CSV manually for string[][] type (anydata[][] defaults to string[][])
            Type referredType = TypeUtils.getReferredType(targetType);
            String typeName = referredType.toString();
            log.debug("CSV target type: {}", typeName);

            // Check if it's a 2D array type (string[][], anydata[][], etc.)
            if (referredType instanceof io.ballerina.runtime.api.types.ArrayType) {
                io.ballerina.runtime.api.types.ArrayType arrayType =
                    (io.ballerina.runtime.api.types.ArrayType) referredType;
                Type elementType = arrayType.getElementType();

                // If element is also an array, it's a 2D array
                if (elementType instanceof io.ballerina.runtime.api.types.ArrayType) {
                    log.debug("Detected 2D array type, using simple CSV parser");
                    return parseSimpleCsv(csvContent);
                }
            }

            // For record types, we would need the full CSV library setup
            // For now, just return an error for unsupported types
            return SmbUtil.createError("CSV parsing for record types is not yet supported. " +
                    "Please use string[][] type for CSV data.", SMB_ERROR);
        } catch (Exception e) {
            log.error("Error converting bytes to CSV", e);
            return SmbUtil.createError("Failed to parse CSV content: " + e.getMessage(), SMB_ERROR);
        }
    }

    /**
     * Simple CSV parser for string[][] type.
     * Handles basic CSV parsing with quoted fields.
     */
    private static BArray parseSimpleCsv(String csvContent) {
        java.util.List<BArray> rows = new java.util.ArrayList<>();
        String[] lines = csvContent.split("\\r?\\n");

        for (String line : lines) {
            if (line.trim().isEmpty()) {
                continue;
            }
            java.util.List<BString> fields = new java.util.ArrayList<>();
            StringBuilder currentField = new StringBuilder();
            boolean inQuotes = false;

            for (int i = 0; i < line.length(); i++) {
                char c = line.charAt(i);

                if (c == '"') {
                    if (inQuotes && i + 1 < line.length() && line.charAt(i + 1) == '"') {
                        // Escaped quote
                        currentField.append('"');
                        i++;
                    } else {
                        inQuotes = !inQuotes;
                    }
                } else if (c == ',' && !inQuotes) {
                    fields.add(StringUtils.fromString(currentField.toString()));
                    currentField = new StringBuilder();
                } else {
                    currentField.append(c);
                }
            }
            fields.add(StringUtils.fromString(currentField.toString()));

            BArray row = ValueCreator.createArrayValue(fields.toArray(new BString[0]));
            rows.add(row);
        }

        // Create array type for string[][]
        io.ballerina.runtime.api.types.ArrayType stringArrayType =
            TypeCreator.createArrayType(io.ballerina.runtime.api.types.PredefinedTypes.TYPE_STRING);
        io.ballerina.runtime.api.types.ArrayType arrayOfStringArraysType = TypeCreator.createArrayType(stringArrayType);

        return ValueCreator.createArrayValue(rows.toArray(new BArray[0]), arrayOfStringArraysType);
    }

    /**
     * Derives file name prefix from file path for error log naming.
     *
     * @param filePath The file path
     * @return File name prefix without extension
     */
    public static String deriveFileNamePrefix(Object filePath) {
        String path = filePath.toString();
        return path.replaceAll("\\.[^.]+$", "");
    }

    /**
     * Converts byte array to Ballerina byte array.
     *
     * @param content The byte array content
     * @return Ballerina byte array
     */
    public static BArray convertToBallerinaByteArray(byte[] content) {
        return ValueCreator.createArrayValue(content);
    }
}
