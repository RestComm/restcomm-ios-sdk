# Sofia SIP wrapper framework

This is an Xcode project that wraps Sofia SIP static library together with boring ssl static library (needed by Sofia for TLS), into an easy to use iOS dynamic framework.

Currently headers aren't exported properly within the framework, so for now we do a lazy hack and copy them over into Headers from Sofia SIP sources. We need to fix this at some point so that headers are copied as part of the build, BUT more importantly the original header hierarchy is respected. If we just copy them in a shallow manner (as is pretty easy via Xcode configuration), then it won't work when the framework is integrated with our higher level SDK, because headers are expected in specific locations.

IMPORTANT: Notice that to use that framework you need to add to your project as an 'Embedded Binary', to make sure it's not shared with other Apps. If you don't do that then you will get a cryptic runtime error

