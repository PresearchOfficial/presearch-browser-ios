
Presearch Privacy Browser for iOS
===============

Download on the [App Store](https://apps.apple.com/us/app/presearch-privacy-browser/id1565192485).

This branch 
-----------

Presearch Privacy Browser is a fork of the Brave Browser. 

Building the code
-----------------

1. Install the latest [Xcode developer tools](https://developer.apple.com/xcode/downloads/) from Apple. (Xcode 11 and up required).
1. Make sure `npm` is installed, `node` version 12 is recommended
1. Install SwiftLint:
    ```shell
    brew update
    brew install swiftlint
    ```
1. Clone the repository:
    ```shell
    git clone https://github.com/PresearchOfficial/presearch-browser-ios.git
    ```
1. Pull in the project dependencies:
    ```shell
    cd brave-ios
    sh ./bootstrap.sh
    ```
1. Open `Client.xcodeproj` in Xcode.
1. Build the `Debug` scheme in Xcode.

### Finding Team IDs

The easiest known way to find your team ID is to log into your [Apple Developer](https://developer.apple.com) account. After logging in, the team ID is currently shown at the end of the URL:
<br>`https://developer.apple.com/account/<TEAM ID>`

Use this string literal in the above, `DevTeam.xcconfig` file to code sign
