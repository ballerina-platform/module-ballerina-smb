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
import io.ballerina.runtime.api.Module;
import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.ArrayType;
import io.ballerina.runtime.api.types.PredefinedTypes;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.types.TypeTags;
import io.ballerina.runtime.api.utils.JsonUtils;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.utils.TypeUtils;
import io.ballerina.runtime.api.utils.XmlUtils;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BString;
import io.ballerina.runtime.api.values.BTypedesc;
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
    public static final String XML = "xml";

    private SmbContentConverter() {
    }

    public static Object convertBytesToJson(byte[] content, Type targetType, boolean laxDataBinding) {
        try {
            String jsonString = new String(content, StandardCharsets.UTF_8);
            return JsonUtils.parse(jsonString);
        } catch (Exception e) {
            return SmbUtil.createError("Failed to parse JSON content: " + e.getMessage(), SMB_ERROR);
        }
    }

    public static Object convertBytesToXml(byte[] content, Type targetType, boolean laxDataBinding) {
        try {
            if (targetType.getQualifiedName().equals(XML)) {
                return XmlUtils.parse(StringUtils.fromString(new String(content, StandardCharsets.UTF_8)));
            }
            BMap<BString, Object> options = createXmlParseOptions(laxDataBinding);
            BTypedesc typedesc = ValueCreator.createTypedescValue(targetType);
            Object bXml = Native.parseBytes(ValueCreator.createArrayValue(content), options, typedesc);
            if (bXml instanceof BError) {
                return SmbUtil.createError(((BError) bXml).getErrorMessage().getValue(), SMB_ERROR);
            }
            return bXml;
        } catch (BError e) {
            return SmbUtil.createError(e.getErrorMessage().getValue(), SMB_ERROR);
        }
    }

    private static BMap<BString, Object> createXmlParseOptions(boolean laxDataBinding) {
        BMap<BString, Object> mapValue = ValueCreator.createRecordValue(
                new Module("ballerina", "data.xmldata", "1"),
                "SourceOptions");
        mapValue.put(StringUtils.fromString("allowDataProjection"), laxDataBinding);
        return mapValue;
    }

    public static Object convertBytesToCsv(Environment env, byte[] content, Type targetType, boolean laxDataBinding,
                                           BMap<?, ?> csvFailSafeConfigs, String fileNamePrefix) {
        try {
            String csvContent = new String(content, StandardCharsets.UTF_8);
            Type referredType = TypeUtils.getReferredType(targetType);
            if (referredType.getTag() == TypeTags.ARRAY_TAG) {
                ArrayType arrayType = (ArrayType) referredType;
                Type elementType = arrayType.getElementType();
                if (elementType.getTag() == TypeTags.ARRAY_TAG) {
                    return parseSimpleCsv(csvContent);
                }
            }
            return SmbUtil.createError("CSV parsing for record types is not yet supported. " +
                    "Please use string[][] type for CSV data.", SMB_ERROR);
        } catch (Exception e) {
            return SmbUtil.createError("Failed to parse CSV content: " + e.getMessage(), SMB_ERROR);
        }
    }

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
        ArrayType stringArrayType = TypeCreator.createArrayType(PredefinedTypes.TYPE_STRING);
        ArrayType arrayOfStringArraysType = TypeCreator.createArrayType(stringArrayType);
        return ValueCreator.createArrayValue(rows.toArray(new BArray[0]), arrayOfStringArraysType);
    }

    public static String deriveFileNamePrefix(Object filePath) {
        String path = filePath.toString();
        return path.replaceAll("\\.[^.]+$", "");
    }
}
