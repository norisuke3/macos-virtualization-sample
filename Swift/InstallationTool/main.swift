/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Tool that sets up the Linux virtual machine environment.
*/

import Foundation

#if arch(arm64)

print("Setting up Linux virtual machine environment...")
install()

#else

print("This tool can only be run on Apple Silicon Macs.")

#endif
