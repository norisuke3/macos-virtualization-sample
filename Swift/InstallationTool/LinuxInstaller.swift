/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Tool that creates the necessary files for running a Linux virtual machine.
*/

import Foundation
import Virtualization

// Create the VM bundle directory
func createVMBundle() {
    let fileManager = FileManager.default
    try! fileManager.createDirectory(at: vmBundleURL, withIntermediateDirectories: true)
}

// Create a new disk image for the Linux installation
func createDiskImage() {
    let diskCreated = FileManager.default.createFile(atPath: diskImageURL.path, contents: nil)
    guard diskCreated else {
        fatalError("Failed to create disk image")
    }
    
    let diskFileHandle = try! FileHandle(forWritingTo: diskImageURL)
    // Create a 64GB disk
    try! diskFileHandle.truncate(atOffset: 64 * 1024 * 1024 * 1024)
}

// Initialize the EFI variable store
func createEFIVariableStore() {
    try! VZEFIVariableStore(creatingVariableStoreAt: auxiliaryStorageURL)
}

// Main installation process
func install() {
    print("Creating VM bundle directory...")
    createVMBundle()
    
    print("Creating disk image...")
    createDiskImage()
    
    print("Initializing EFI variable store...")
    createEFIVariableStore()
    
    print("Installation completed successfully.")
    print("You can now run the virtual machine app to install Linux from the ISO.")
}

// Run the installation
install()
