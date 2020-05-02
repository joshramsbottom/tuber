//
//  TuberViewController.swift
//  tuber
//
//  Created by Joshua Ramsbottom on 2020/05/01.
//  Copyright © 2020 jramsbottom. All rights reserved.
//

import Cocoa

class TuberViewController: NSViewController {
    
    @IBOutlet var urlTextField: NSTextField!
    @IBOutlet var downloadProgressBar: NSProgressIndicator!
    @IBOutlet var downloadButton: NSButton!
    @IBOutlet var feedbackLabel: NSTextField!
    
    var downloadTask: Process!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
}

extension TuberViewController {
    static func freshController() -> TuberViewController {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier("TuberViewController")
        guard let viewController = storyboard.instantiateController(withIdentifier: identifier) as? TuberViewController else {
            fatalError("Can't find TuberViewController - Check Main.storyboard")
        }
        return viewController
    }
}

extension TuberViewController {
    @IBAction func download(_ sender: NSButton) {
        downloadButton.isEnabled = false
        feedbackLabel.stringValue = ""

        // Find location of youtube-dl
        let whichTask = Process()
        let whichOutputPipe = Pipe()
        
        whichTask.launchPath = "/bin/bash"
        whichTask.arguments = ["-l", "-c", "which youtube-dl"]
        whichTask.standardOutput = whichOutputPipe
        
        whichTask.launch()
        
        let whichTaskData = whichOutputPipe.fileHandleForReading.readDataToEndOfFile()
        let youtubeDLCommand = String(data: whichTaskData, encoding: String.Encoding.utf8)?.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
        let url = urlTextField.stringValue

        // Validate URL
        if !url.isValidURL {
            self.downloadButton.isEnabled = true
            self.feedbackLabel.stringValue = "Invalid URL"
            return;
        }

        downloadProgressBar.doubleValue = 0.0
        feedbackLabel.stringValue = "Downloading..."
        
        // Download video
        DispatchQueue.global().async {
            self.downloadTask = Process()
            let outputPipe = Pipe()

            self.downloadTask.launchPath = youtubeDLCommand
            self.downloadTask.arguments = ["-o", "~/Downloads/%(title)s.%(ext)s", url]
            self.downloadTask.standardOutput = outputPipe

            outputPipe.fileHandleForReading.readabilityHandler = { (fileHandle) -> Void in
                let availableData = fileHandle.availableData
                let newOutput = String(data: availableData, encoding: .utf8)
                let lines = newOutput!.split { $0.isNewline }
                let lastLine = lines.last
                var percentage: String? = nil
                if let lastLine = lastLine {
                    let tokens = lastLine.split { $0.isWhitespace }
                    percentage = String(tokens[1].dropLast())
                }

                // Update UI
                if let percentage = percentage {
                    if let percentageDouble = Double(percentage) {
                        DispatchQueue.main.async {
                            if self.downloadProgressBar.doubleValue != 100.0 {
                                self.downloadProgressBar.doubleValue = percentageDouble
                            }
                        }
                    }
                }
            }
    
            self.downloadTask.launch()
            self.downloadTask.waitUntilExit()
            
            DispatchQueue.main.async {
                self.downloadButton.isEnabled = true
                if self.downloadProgressBar.doubleValue == 100.0 {
                    self.feedbackLabel.stringValue = "Download complete"
                }
            }
        }
    }
}

extension String {
    var isValidURL: Bool {
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        if let match = detector.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count)) {
            return match.range.length == self.utf16.count
        } else {
            return false
        }
    }
}
