// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/jballerina.java;
import ballerina/task;

# Listener for monitoring SMB servers and triggering service functions when files are added or deleted.
public isolated class Listener {
    private handle EMPTY_JAVA_STRING = java:fromString("");
    private ListenerConfiguration config = {};
    private task:JobId? jobId = ();

    # Gets invoked during object initialization.
    #
    # + listenerConfig - Configurations for SMB listener
    # + return - `()` or else an `smb:Error` upon failure to initialize the listener
    public isolated function init(*ListenerConfiguration listenerConfig) returns Error? {
        self.config = listenerConfig.clone();
        lock {
            return initListener(self, self.config);
        }
    }

    # Starts the SMB listener and begins monitoring for file changes.
    # ```ballerina
    # error? response = listener.'start();
    # ```
    #
    # + return - `()` or else an `error` upon failure to start the listener
    public isolated function 'start() returns error? {
        return self.internalStart();
    }

    # Attaches an SMB service to the listener.
    # ```ballerina
    # error? response = listener.attach(service1);
    # ```
    #
    # + smbService - Service to be attached to the listener
    # + name - Optional name for the service
    # + return - `()` or else an `error` upon failure to attach the service
    public isolated function attach(Service smbService, string[]|string? name = ()) returns error? {
        if name is string? {
            return self.register(smbService, name);
        }
    }

    # Stops the SMB listener and detaches the service.
    # ```ballerina
    # error? response = listener.detach(service1);
    # ```
    #
    # + smbService - Service to be detached from the listener
    # + return - `()` or else an `error` upon failure to detach the service
    public isolated function detach(Service smbService) returns error? {
        check self.stop();
        return deregister(self, smbService);
    }

    # Stops the SMB listener immediately.
    # ```ballerina
    # error? response = listener.immediateStop();
    # ```
    #
    # + return - `()` or else an `error` upon failure to stop the listener
    public isolated function immediateStop() returns error? {
        check self.stop();
    }

    # Stops the SMB listener gracefully.
    # ```ballerina
    # error? response = listener.gracefulStop();
    # ```
    #
    # + return - `()` or else an `error` upon failure to stop the listener
    public isolated function gracefulStop() returns error? {
        check self.stop();
    }

    isolated function internalStart() returns error? {
        lock {
            self.jobId = check task:scheduleJobRecurByFrequency(new Job(self), self.config.pollingInterval);
        }
    }

    isolated function stop() returns error? {
        lock {
            var id = self.jobId;
            if id is task:JobId {
                check task:unscheduleJob(id);
                self.jobId = ();
            }
            return cleanup(self);
        }
    }

    # Polls the SMB server for new or deleted files.
    # ```ballerina
    # error? response = listener.poll();
    # ```
    #
    # + return - An `error` if failed to establish communication with the SMB server
    public isolated function poll() returns error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.server.SmbListenerHelper"
    } external;

    # Registers an SMB service with the listener.
    # ```ballerina
    # error? response = listener.register(smbService, name);
    # ```
    #
    # + smbService - The SMB service to register
    # + name - Optional name of the service
    # + return - An `error` if failed to establish communication with the SMB server
    public isolated function register(Service smbService, string? name) returns error? = @java:Method {
        'class: "io.ballerina.stdlib.smb.server.SmbListenerHelper"
    } external;
}

isolated function initListener(Listener listenerEndpoint, ListenerConfiguration config)
        returns Error? = @java:Method {
    name: "init",
    'class: "io.ballerina.stdlib.smb.server.SmbListenerHelper"
} external;

isolated function deregister(Listener listenerEndpoint, Service smbService) returns Error? = @java:Method {
    'class: "io.ballerina.stdlib.smb.server.SmbListenerHelper"
} external;

isolated function cleanup(Listener listenerEndpoint) returns Error? = @java:Method {
    'class: "io.ballerina.stdlib.smb.server.SmbListenerHelper"
} external;

class Job {

    *task:Job;
    private Listener smbListener;

    public isolated function execute() {
        error? result = self.smbListener.poll();
    }

    public isolated function init(Listener initializedListener) {
        self.smbListener = initializedListener;
    }
}
