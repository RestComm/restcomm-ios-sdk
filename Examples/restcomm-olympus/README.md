# Restcomm Olympus Demo App

This is the pod version of the Olympus Demo App (i.e. using pods for dependencies instead of plain old libraries + frameworks). Notice the sources aren't hosted in this directory, but pulled via a symbolic link from ../restcomm-olympus-nopod (i.e. the original Xcode library App project), so that we can maintain both side by side. 

The reason we keep 2 separate projects with same source files, is to make it easier to build any flavor, since at times we need both of them

