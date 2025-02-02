//
//  ProcessResult.swift
//  rBUM
//
//  Created by Matthew Yeager on 02/02/2025.
//

import Foundation

/// Namespace for core types and utilities
enum Core {}

extension Core {
    /// Result of a process execution
    struct ProcessResult {
        /// Exit code of the process
        let exitCode: Int
        
        /// Standard output from the process
        let output: String
        
        /// Standard error from the process
        let error: String
    }
}
