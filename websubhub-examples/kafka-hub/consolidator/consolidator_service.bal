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

import ballerinax/kafka;
import ballerina/websubhub;
import ballerina/lang.value;
import ballerina/log;
import consolidatorService.config;
import consolidatorService.util;
import consolidatorService.connections as conn;
import consolidatorService.persistence as persist;

public function main() returns error? {
    // Start consolidation service
    log:printInfo("Starting subscription consolidation service");
}

isolated map<websubhub:VerifiedSubscription> subscribersCache = {};

listener kafka:Listener kafkaListener = check new (config:KAFKA_BOOTSTRAP_NODE, conn:subscribersConsumerConfig);

service kafka:Service on kafkaListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:ConsumerRecord[] records) returns error? {
        foreach kafka:ConsumerRecord 'record in records {
            string lastPersistedData = check string:fromBytes('record.value);
            var subscriberEvent = deSerializeSubscriberEvents(lastPersistedData);
            if !(subscriberEvent is error) {
                check persistConsolidatedSubscriptions(subscriberEvent);
            }
        }
        kafka:Error? commitResult = caller->commit();
        if commitResult is error {
            log:printError("Error occurred while committing the offsets for the consumer ", 'error = commitResult);
        }
    }
}

function persistConsolidatedSubscriptions(websubhub:VerifiedSubscription|websubhub:VerifiedUnsubscription event) returns error? {
    refreshSubscribersCache(event);
    lock {
        _ = check persist:persistSubscriptions(subscribersCache);
    } 
}

function deSerializeSubscriberEvents(string lastPersistedData) returns websubhub:VerifiedSubscription|websubhub:VerifiedUnsubscription|error {
    websubhub:VerifiedSubscription[] currentSubscriptions = [];
    json payload =  check value:fromJsonString(lastPersistedData);
    string hubMode = check payload.hubMode;
    match hubMode {
        "subscribe" => {
            return check payload.cloneWithType(websubhub:VerifiedSubscription);
        }
        "unsubscribe" => {
            return check payload.cloneWithType(websubhub:VerifiedUnsubscription);
        }
        _ => {
            return error(string `Error occurred while deserializing subscriber events with invalid hubMode [${hubMode}]`);
        }
    }
}

function refreshSubscribersCache(websubhub:VerifiedSubscription|websubhub:VerifiedUnsubscription event) {
    string groupName = util:generateGroupName(event.hubTopic, event.hubCallback);
    if event is websubhub:VerifiedSubscription {
        lock {
            // add the subscriber if subscription event received
            if !subscribersCache.hasKey(groupName) {
                subscribersCache[groupName] = event.cloneReadOnly();
            }
        }
    } else {
        // remove the subscriber if the unsubscription event received
        lock {
            _ = subscribersCache.removeIfHasKey(groupName);
        }
    }
}
