//
//  main.swift
//  ResticService
//
//  Created by Matthew Yeager on 05/02/2025.
//

import Foundation
import Core

// Create the delegate for the service.
let serviceDelegate = ServiceDelegate()

// Set up the one NSXPCListener for this service. It will handle all incoming connections.
let serviceListener = NSXPCListener.service()
serviceListener.delegate = serviceDelegate

// Resuming the serviceListener starts this service. This method does not return.
serviceListener.resume()
