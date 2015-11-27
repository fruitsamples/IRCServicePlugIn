IRCServicePlugIn

A sample IMServicePlugIn implementing the IRC protocol. Shows how to use IMServicePlugIn, IMServicePlugInGroupListSupport, IMServicePlugInGroupListHandlePictureSupport, IMServicePlugInInstantMessagingSupport, IMServicePlugInChatRoomSupport and IMServicePlugInPresenceSupport protocols in a service plugin and also how to utilize IMServiceApplication, IMServiceApplicationGroupListSupport, IMServiceApplicationInstantMessagingSupport and IMServiceApplicationChatRoomSupport to make callbacks to iChat.

==== Project Setup ====

To set up your project in Xcode 4.1 or higher:

1) Open Xcode
2) File->New->New Project
3) Select Framework & Library
4) Click Bundle then Next
5) Name your project (IRCServicePlugin in this case)
6) Hit Next then Create
7) Select the bundle target in the project editor
8) Change the "Wrapper Extension" to "imserviceplugin"
9) Change the "Installation Directory" to "/Library/iChat/PlugIns" for a system install or "~/Library/iChat/PlugIns" for a user install
10) Change the "Product Name" if desired, in this case it was changed to just "IRC"
11) Edit the Info.plist to add the IMServiceCapabilities your project supports, in the IRC case it is set to the following:
	IMServiceCapabilityInstantMessagingSupport
	IMServiceCapabilityChatRoomSupport
	IMServiceCapabilityGroupListSupport
	IMServiceCapabilityGroupListHandlePictureSupport
	IMServiceCapabilityGroupListHandlePictureSupport
12) Edit the IM settings in the Info.plist to any non-default settings, IRC has the following set:
	IMUsesEnableSSLAccountSetting=NO
	IMUsesPasswordAccountSetting=NO
	IMDefaultServerPortAccountSetting=6667
13) Edit the Principal Class in Info.plist to point to the class that implements the protocols listed as supported. For IRC it's set to IRCServicePlugIn.

==== Testing and Debugging ====

To test your plugin, link or copy it to /Library/iChat/PlugIns, quit iChat and run "killall imagent" from the Terminal. It should then show up in iChat when you try to add a new account.

To debug the plugin, disable all other accounts in iChat and attach to IMServicePlugInAgent in Xcode from Product->Attach to Process.
