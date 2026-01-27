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

import io.ballerina.lib.data.ModuleUtils;
import io.ballerina.lib.data.xmldata.xml.Native;
import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.Module;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.types.TypeTags;
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

import java.io.File;
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
    public static final BString FILE_PATH = StringUtils.fromString("filePath");
    public static final BString FILE_OUTPUT_MODE = StringUtils.fromString("fileOutputMode");
    public static final BString FAIL_SAFE = StringUtils.fromString("failSafe");
    public static final String FAIL_SAFE_OPTIONS = "FailSafeOptions";
    public static final String FILE_OUTPUT_MODE_TYPE = "FileOutputMode";
    public static final String XML = "xml";

    private SmbContentConverter() {
    }

    public static Object convertBytesToJson(byte[] content, Type targetType, boolean laxDataBinding) {
        try {
            BArray byteArray = ValueCreator.createArrayValue(content);
            BMap<BString, Object> options = createJsonParseOptions(laxDataBinding);
            BTypedesc typedesc = ValueCreator.createTypedescValue(targetType);

            Object result = io.ballerina.lib.data.jsondata.json.Native.parseBytes(byteArray, options, typedesc);
            if (TypeUtils.getType(result).getTag() == TypeTags.ERROR_TAG) {
                return SmbUtil.createError(((BError) result).getErrorMessage().getValue(), SMB_ERROR);
            }
            return result;
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
            BArray byteArray = ValueCreator.createArrayValue(content);
            BMap<BString, Object> options = createCsvParseOptions(laxDataBinding, csvFailSafeConfigs, fileNamePrefix);

            Type referredType = TypeUtils.getReferredType(targetType);
            BTypedesc typedesc = ValueCreator.createTypedescValue(referredType);

            Object result = io.ballerina.lib.data.csvdata.csv.Native.parseBytes(env, byteArray, options, typedesc);

            if (result instanceof BError) {
                return SmbUtil.createError("Failed to parse CSV content: " + ((BError) result).getErrorMessage(),
                        SMB_ERROR);
            }

            return result;
        } catch (Exception e) {
            return SmbUtil.createError("Failed to parse CSV content: " + e.getMessage(), SMB_ERROR);
        }
    }

    @SuppressWarnings("unchecked")
    private static BMap<BString, Object> createJsonParseOptions(boolean laxDataBinding) {
        BMap<BString, Object> mapValue = ValueCreator.createRecordValue(ModuleUtils.getModule(), "Options");
        if (laxDataBinding) {
            BMap<BString, Object> allowDataProjection =
                    (BMap<BString, Object>) mapValue.getMapValue(StringUtils.fromString("allowDataProjection"));
            allowDataProjection.put(StringUtils.fromString("nilAsOptionalField"), Boolean.TRUE);
            allowDataProjection.put(StringUtils.fromString("absentAsNilableType"), Boolean.TRUE);
            mapValue.put(StringUtils.fromString("allowDataProjection"), allowDataProjection);
        } else {
            mapValue.put(StringUtils.fromString("allowDataProjection"), Boolean.FALSE);
        }
        return mapValue;
    }

    @SuppressWarnings("unchecked")
    private static BMap<BString, Object> createCsvParseOptions(boolean laxDataBinding,
                                                               BMap<?, ?> csvFailSafeConfigs, String fileNamePrefix) {
        BMap<BString, Object> mapValue = ValueCreator.createRecordValue(
                io.ballerina.lib.data.csvdata.utils.ModuleUtils.getModule(), "ParseOptions");
        if (csvFailSafeConfigs != null) {
            BString contentType = csvFailSafeConfigs.getStringValue(CONTENT_TYPE);
            BMap<BString, Object> failSafe =
                    ValueCreator.createRecordValue(io.ballerina.lib.data.csvdata.utils.ModuleUtils.getModule(),
                            FAIL_SAFE_OPTIONS);
            BMap<BString, Object> fileOutputMode =
                    ValueCreator.createRecordValue(io.ballerina.lib.data.csvdata.utils.ModuleUtils.getModule(),
                            FILE_OUTPUT_MODE_TYPE);
            String filePath = CURRENT_DIRECTORY_PATH + File.separator + fileNamePrefix + "_" + ERROR_LOG_FILE_NAME;
            fileOutputMode.put(FILE_PATH, StringUtils.fromString(filePath));
            fileOutputMode.put(FILE_WRITE_OPTION, APPEND);
            fileOutputMode.put(CONTENT_TYPE, contentType);
            failSafe.put(FILE_OUTPUT_MODE, fileOutputMode);
            mapValue.put(FAIL_SAFE, failSafe);
        }
        if (laxDataBinding) {
            BMap<BString, Object> allowDataProjection =
                    (BMap<BString, Object>) mapValue.getMapValue(StringUtils.fromString("allowDataProjection"));
            allowDataProjection.put(StringUtils.fromString("nilAsOptionalField"), Boolean.TRUE);
            allowDataProjection.put(StringUtils.fromString("absentAsNilableType"), Boolean.TRUE);
            mapValue.put(StringUtils.fromString("allowDataProjection"), allowDataProjection);
        } else {
            mapValue.put(StringUtils.fromString("allowDataProjection"), Boolean.FALSE);
        }
        return mapValue;
    }

    public static String deriveFileNamePrefix(Object filePath) {
        String path = filePath.toString();
        return path.replaceAll("\\.[^.]+$", "");
    }
}
