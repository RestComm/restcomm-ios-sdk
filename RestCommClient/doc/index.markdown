RestComm iOS Client allows you to leverage the telecommunication features of RestComm. It offers a simple yet efficient Objective-C API that you can use to add rich communications capabilities to your iOS Apps.

You access the communication features of RestComm Client through two main entities: RCDevice and RCConnection.

- RCDevice is an abstraction of a communications device that can initiate/receive calls and send/receive messages.
- RCConnection represents a media connection between two parties.

In order to get advantage of the event mechanism offered by RestComm Client you need to set a delegate to RCDevice which will be receiving any RCDevice or RCConnection events such as incoming calls and messages.
