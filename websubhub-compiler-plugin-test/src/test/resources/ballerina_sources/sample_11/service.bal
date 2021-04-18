import ballerina/websubhub;
import ballerina/http;
import ballerina/io;

listener http:Listener httpListener = new http:Listener(10012);
websubhub:ListenerConfiguration listenerConfig = {
    secureSocket: {
        key: {
            path: "tests/resources/ballerinaKeystore.pkcs12",
            password: "ballerina"
        }
    }
};

service /websubhub on new websubhub:Listener(httpListener, listenerConfig) {

    isolated remote function onRegisterTopic(websubhub:TopicRegistration message)
                                returns websubhub:TopicRegistrationSuccess|websubhub:TopicRegistrationError {
        if (message.topic == "test") {
            return websubhub:TOPIC_REGISTRATION_SUCCESS;
        } else {
            return websubhub:TOPIC_REGISTRATION_ERROR;
        }
    }

    isolated remote function onDeregisterTopic(websubhub:TopicDeregistration message, http:Request baseRequest)
                        returns websubhub:TopicDeregistrationSuccess|websubhub:TopicDeregistrationError {

        map<string> body = { isDeregisterSuccess: "true" };
        websubhub:TopicDeregistrationSuccess deregisterResult = {
            body
        };
        if (message.topic == "test") {
            return deregisterResult;
       } else {
            return error websubhub:TopicDeregistrationError("Topic Deregistration Failed!");
        }
    }

    isolated remote function onUpdateMessage(websubhub:UpdateMessage message)
               returns websubhub:Acknowledgement|websubhub:UpdateMessageError {
        return websubhub:ACKNOWLEDGEMENT;
    }
    
    isolated remote function onSubscription(websubhub:Subscription msg)
                returns websubhub:SubscriptionAccepted|websubhub:SubscriptionPermanentRedirect|websubhub:SubscriptionTemporaryRedirect
                |websubhub:BadSubscriptionError|websubhub:InternalSubscriptionError {
        websubhub:SubscriptionAccepted successResult = {
                body: <map<string>>{
                       isSuccess: "true"
                    }
            };
        if (msg.hubTopic == "test") {
            return successResult;
        } else if (msg.hubTopic == "test1") {
            return successResult;
        } else {
            return error websubhub:BadSubscriptionError("Bad subscription");
        }
    }

    isolated remote function onSubscriptionValidation(websubhub:Subscription msg)
                returns websubhub:SubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return error websubhub:SubscriptionDeniedError("Denied subscription for topic 'test1'");
        }
        return ();
    }

    isolated remote function onSubscriptionIntentVerified(websubhub:VerifiedSubscription msg) {
        io:println("Subscription Intent verified invoked!");
    }

    isolated remote function onUnsubscription(websubhub:Unsubscription msg)
               returns websubhub:UnsubscriptionAccepted|websubhub:BadUnsubscriptionError|websubhub:InternalUnsubscriptionError {
        if (msg.hubTopic == "test" || msg.hubTopic == "test1" ) {
            websubhub:UnsubscriptionAccepted successResult = {
                body: <map<string>>{
                       isSuccess: "true"
                    }
            };
            return successResult;
        } else {
            return error websubhub:BadUnsubscriptionError("Denied unsubscription for topic '" + <string> msg.hubTopic + "'");
        }
    }

    isolated remote function onUnsubscriptionValidation(websubhub:Unsubscription msg)
                returns websubhub:UnsubscriptionDeniedError? {
        if (msg.hubTopic == "test1") {
            return error websubhub:UnsubscriptionDeniedError("Denied subscription for topic 'test1'");
        }
        return ();
    }

    isolated remote function onUnsubscriptionIntentVerified(websubhub:VerifiedUnsubscription msg){
        io:println("Unsubscription Intent verified invoked!");
    }
}