//
//  main.swift
//  rBUM
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  First created: 6 February 2025
//  Last updated: 6 February 2025
//
//  Created by Matthew Yeager on 05/02/2025.
//

import Core
import Foundation

// Create the delegate for the service.
let serviceDelegate = ServiceDelegate()

// Set up the one NSXPCListener for this service. It will handle all incoming connections.
let serviceListener = NSXPCListener.service()
serviceListener.delegate = serviceDelegate

// Resuming the serviceListener starts this service. This method does not return.
serviceListener.resume()
