/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app delegate that sets up and starts the virtual machine.
*/

import Cocoa
import Foundation
import Virtualization

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet var window: NSWindow!

    @IBOutlet weak var virtualMachineView: VZVirtualMachineView!

    private var virtualMachine: VZVirtualMachine!

    // MARK: Create the virtual machine configuration and instantiate the virtual machine.

    private func createVirtualMachine() {
        // Check if VM is installed
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: vmBundlePath),
              fileManager.fileExists(atPath: diskImageURL.path),
              fileManager.fileExists(atPath: auxiliaryStorageURL.path) else {
            fatalError("VM is not installed. Please run InstallationTool first to set up the Linux VM.")
        }

        let virtualMachineConfiguration = VZVirtualMachineConfiguration()

        // Set up CPU and memory
        virtualMachineConfiguration.cpuCount = 4
        virtualMachineConfiguration.memorySize = 4 * 1024 * 1024 * 1024 // 4GB

        // Set up EFI boot loader with existing variable store
        guard let efiVariableStore = try? VZEFIVariableStore(url: auxiliaryStorageURL) else {
            fatalError("Failed to load EFI variable store. The VM might be corrupted.")
        }
        let bootLoader = VZEFIBootLoader(variableStore: efiVariableStore)
        virtualMachineConfiguration.bootLoader = bootLoader

        // Set up graphics device
        let graphicsDevice = VZVirtioGraphicsDeviceConfiguration()
        let display = VZVirtioGraphicsDisplayConfiguration(widthInPixels: 1280, heightInPixels: 800)
        graphicsDevice.displays = [display]
        virtualMachineConfiguration.graphicsDevices = [graphicsDevice]

        // Set up storage devices
        guard let mainDiskAttachment = try? VZDiskImageStorageDeviceAttachment(url: diskImageURL, readOnly: false) else {
            fatalError("Failed to attach main disk. The disk image might be corrupted.")
        }
        let mainDisk = VZVirtioBlockDeviceConfiguration(attachment: mainDiskAttachment)
        virtualMachineConfiguration.storageDevices = [mainDisk]

        // Set up network device
        let networkDevice = VZVirtioNetworkDeviceConfiguration()
        networkDevice.attachment = VZNATNetworkDeviceAttachment()
        virtualMachineConfiguration.networkDevices = [networkDevice]

        // Set up input devices
        let keyboard = VZUSBKeyboardConfiguration()
        virtualMachineConfiguration.keyboards = [keyboard]
        
        let pointingDevice = VZUSBScreenCoordinatePointingDeviceConfiguration()
        virtualMachineConfiguration.pointingDevices = [pointingDevice]

        // Add shared directory configuration
        let sharedDirectory = VZSharedDirectory(url: URL(fileURLWithPath: sharedDirectoryPath), readOnly: false)
        let share = VZSingleDirectoryShare(directory: sharedDirectory)
        let fileSystemDevice = VZVirtioFileSystemDeviceConfiguration(tag: "com.apple.virtio-fs.automount")
        fileSystemDevice.share = share
        virtualMachineConfiguration.directorySharingDevices = [fileSystemDevice]

        try! virtualMachineConfiguration.validate()

        if #available(macOS 14.0, *) {
            try! virtualMachineConfiguration.validateSaveRestoreSupport()
        }

        virtualMachine = VZVirtualMachine(configuration: virtualMachineConfiguration)
    }

    // MARK: Start or restore the virtual machine.

    func startVirtualMachine() {
        virtualMachine.start(completionHandler: { (result) in
            if case let .failure(error) = result {
                fatalError("Virtual machine failed to start with \(error)")
            }
        })
    }

    func resumeVirtualMachine() {
        virtualMachine.resume(completionHandler: { (result) in
            if case let .failure(error) = result {
                fatalError("Virtual machine failed to resume with \(error)")
            }
        })
    }

    @available(macOS 14.0, *)
    func restoreVirtualMachine() {
        virtualMachine.restoreMachineStateFrom(url: saveFileURL, completionHandler: { [self] (error) in
            // Remove the saved file. Whether success or failure, the state no longer matches the VM's disk.
            let fileManager = FileManager.default
            try! fileManager.removeItem(at: saveFileURL)

            if error == nil {
                self.resumeVirtualMachine()
            } else {
                self.startVirtualMachine()
            }
        })
    }
#endif

    func applicationDidFinishLaunching(_ aNotification: Notification) {
#if arch(arm64)
        print("Starting Linux virtual machine...")
        DispatchQueue.main.async { [self] in
            createVirtualMachine()
            virtualMachineView.virtualMachine = virtualMachine
            virtualMachineView.capturesSystemKeys = true

            if #available(macOS 14.0, *) {
                virtualMachineView.automaticallyReconfiguresDisplay = true
            }

            startVirtualMachine()
        }
#else
        print("This app can only run on Apple Silicon Macs.")
#endif
    }

    // MARK: Save the virtual machine when the app exits.

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
#if arch(arm64)
    @available(macOS 14.0, *)
    func saveVirtualMachine(completionHandler: @escaping () -> Void) {
        virtualMachine.saveMachineStateTo(url: saveFileURL, completionHandler: { (error) in
            guard error == nil else {
                fatalError("Virtual machine failed to save with \(error!)")
            }

            completionHandler()
        })
    }

    @available(macOS 14.0, *)
    func pauseAndSaveVirtualMachine(completionHandler: @escaping () -> Void) {
        virtualMachine.pause(completionHandler: { (result) in
            if case let .failure(error) = result {
                fatalError("Virtual machine failed to pause with \(error)")
            }

            self.saveVirtualMachine(completionHandler: completionHandler)
        })
    }
#endif

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
#if arch(arm64)
        if #available(macOS 14.0, *) {
            if virtualMachine.state == .running {
                pauseAndSaveVirtualMachine(completionHandler: {
                    sender.reply(toApplicationShouldTerminate: true)
                })
                
                return .terminateLater
            }
        }
#endif

        return .terminateNow
    }
}
