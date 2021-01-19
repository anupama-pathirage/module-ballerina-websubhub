// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

import ballerina/http;
import ballerina/log;
import ballerina/java;

service class HttpService {
    private HubService hubService;
    private boolean isSubscriptionAvailable = false;
    private boolean isSubscriptionValidationAvailable = false;
    private boolean isUnsubscriptionAvailable = false;

    public isolated function init(HubService hubService) {
        self.hubService = hubService;

        string[] methodNames = getServiceMethodNames(hubService);
        foreach var methodName in methodNames {
            if (methodName == "onSubscription") {
                self.isSubscriptionAvailable = true;
                break;
            } else {
                self.isSubscriptionAvailable = false;
            }
        }

        foreach var methodName in methodNames {
            if (methodName == "onSubscriptionValidation") {
                self.isSubscriptionValidationAvailable = true;
                break;
            } else {
                self.isSubscriptionValidationAvailable = false;
            }
        }

        foreach var methodName in methodNames {
            if (methodName == "onUnsubscription") {
                self.isUnsubscriptionAvailable = true;
                break;
            } else {
               self.isUnsubscriptionAvailable = false;
            }
        }
    }

    resource function post .(http:Caller caller, http:Request request) {
        http:Response response = new;
        response.statusCode = http:STATUS_OK;

        var reqFormParamMap = request.getFormParams();
        map<string> params = reqFormParamMap is map<string> ? reqFormParamMap : {};

        string mode = params[HUB_MODE] ?: "";
        match mode {
            MODE_REGISTER => {
                processRegisterRequest(caller, response, <@untainted> params, self.hubService);
                respondToRequest(caller, response);
            }
            MODE_UNREGISTER => {
                processUnregisterRequest(caller, response, <@untainted> params, self.hubService);
                respondToRequest(caller, response);
            }
            MODE_SUBSCRIBE => {
                processSubscriptionRequestAndRespond(caller, response, <@untainted> params, 
                                                        <@untainted> self.hubService,
                                                        <@untainted> self.isSubscriptionAvailable,
                                                        <@untainted> self.isSubscriptionValidationAvailable);
            }
            MODE_UNSUBSCRIBE => {
                processUnsubscriptionRequestAndRespond(caller, response, <@untainted> params,
                                                        self.hubService, self.isUnsubscriptionAvailable);
            }
            _ => {
                response.statusCode = http:STATUS_BAD_REQUEST;
                string errorMessage = "The request need to include valid `hub.mode` form param";
                response.setTextPayload(errorMessage);
                log:print("Hub request unsuccessful :" + errorMessage);
                respondToRequest(caller, response);
            }
        }
    }
}

isolated function getServiceMethodNames(HubService hubService) returns string[] = @java:Method {
    'class: "io.ballerina.stdlib.websubhub.HubNativeOperationHandler"
} external;
