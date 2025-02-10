import Foundation

/// Service for exporting performance reports in various formats
public struct PerformanceReportExporter {
    /// Available export formats
    public enum ExportFormat {
        /// Comma-separated values format
        case csv
        /// JavaScript Object Notation format
        case json
        /// Portable Document Format
        case pdf

        /// File extension for the format
        var fileExtension: String {
            switch self {
            case .csv: "csv"
            case .json: "json"
            case .pdf: "pdf"
            }
        }
    }

    /// Export configuration options
    public struct ExportConfig {
        /// Whether to include alerts in the export
        public let includeAlerts: Bool
        /// Whether to include raw performance metrics
        public let includeRawMetrics: Bool
        /// Time zone for date formatting
        public let timeZone: TimeZone
        /// Format string for dates in the export
        public let dateFormat: String

        /// Initialises a new export configuration
        /// - Parameters:
        ///   - includeAlerts: Whether to include alerts (default: true)
        ///   - includeRawMetrics: Whether to include raw metrics (default: true)
        ///   - timeZone: Time zone for date formatting (default: current)
        ///   - dateFormat: Format string for dates (default: "dd/MM/yyyy HH:mm:ss")
        public init(
            includeAlerts: Bool = true,
            includeRawMetrics: Bool = true,
            timeZone: TimeZone = .current,
            dateFormat: String = "dd/MM/yyyy HH:mm:ss"
        ) {
            self.includeAlerts = includeAlerts
            self.includeRawMetrics = includeRawMetrics
            self.timeZone = timeZone
            self.dateFormat = dateFormat
        }
    }

    private let dateFormatter: DateFormatter

    /// Initialises a new performance report exporter
    /// - Parameter timeZone: Time zone for date formatting (default: current)
    public init(timeZone: TimeZone = .current) {
        dateFormatter = DateFormatter()
        dateFormatter.timeZone = timeZone
    }

    /// Export performance report to specified format
    /// - Parameters:
    ///   - report: Performance report to export
    ///   - alerts: Optional alerts to include
    ///   - format: Export format
    ///   - config: Export configuration
    /// - Returns: Exported data
    public func export(
        report: PerformanceReport,
        alerts: [PerformanceAlert],
        format: ExportFormat,
        config: ExportConfig
    ) throws -> Data {
        dateFormatter.dateFormat = config.dateFormat
        dateFormatter.timeZone = config.timeZone

        switch format {
        case .csv:
            return try exportToCSV(report: report, alerts: alerts, config: config)
        case .json:
            return try exportToJSON(report: report, alerts: alerts, config: config)
        case .pdf:
            return try exportToPDF(report: report, alerts: alerts, config: config)
        }
    }

    // MARK: - Private Methods

    private func exportToCSV(
        report: PerformanceReport,
        alerts: [PerformanceAlert],
        config: ExportConfig
    ) throws -> Data {
        var csvString = "Performance Report\n"
        csvString += "Period: \(formatDate(report.period.start)) - \(formatDate(report.period.end))\n\n"

        // Summary Statistics
        csvString += "Summary Statistics\n"
        csvString += "Average Operation Duration (ms),\(report.statistics.averageOperationDuration)\n"
        csvString += "Operation Success Rate (%),\(report.statistics.operationSuccessRate)\n"
        csvString += "Peak Memory Usage (bytes),\(report.statistics.peakMemoryUsage)\n"
        csvString += "Average CPU Usage (%),\(report.statistics.averageCPUUsage)\n"
        csvString += "Peak CPU Usage (%),\(report.statistics.peakCPUUsage)\n"
        csvString += "Average Backup Speed (B/s),\(report.statistics.averageBackupSpeed)\n"
        csvString += "Total Operations,\(report.statistics.totalOperations)\n"
        csvString += "Failed Operations,\(report.statistics.failedOperations)\n\n"

        if config.includeRawMetrics {
            csvString += "\nRaw Metrics\n"
            csvString += "Timestamp,Metric,Value,Unit\n"
            for metric in report.metrics {
                let timestamp = formatDate(metric.timestamp)
                csvString += "\(timestamp),\(metric.name),\(metric.value),\(metric.unit.description)\n"
            }
        }

        if config.includeAlerts, !alerts.isEmpty {
            csvString += "\nPerformance Alerts\n"
            csvString += "Timestamp,Severity,Type,Message\n"
            for alert in alerts {
                let timestamp = formatDate(alert.timestamp)
                let severity = String(describing: alert.severity)
                let type = alert.type.localizedDescription
                csvString += "\(timestamp),\(severity),\(type),\(alert.message)\n"
            }
        }

        return csvString.data(using: .utf8) ?? Data()
    }

    private func exportToJSON(
        report: PerformanceReport,
        alerts: [PerformanceAlert],
        config: ExportConfig
    ) throws -> Data {
        var json: [String: Any] = [
            "period": [
                "start": formatDate(report.period.start),
                "end": formatDate(report.period.end),
            ],
            "statistics": [
                "averageOperationDuration": report.statistics.averageOperationDuration,
                "operationSuccessRate": report.statistics.operationSuccessRate,
                "peakMemoryUsage": report.statistics.peakMemoryUsage,
                "averageCPUUsage": report.statistics.averageCPUUsage,
                "peakCPUUsage": report.statistics.peakCPUUsage,
                "averageBackupSpeed": report.statistics.averageBackupSpeed,
                "totalOperations": report.statistics.totalOperations,
                "failedOperations": report.statistics.failedOperations,
            ],
        ]

        if config.includeRawMetrics {
            json["metrics"] = report.metrics.map { metric in
                [
                    "timestamp": formatDate(metric.timestamp),
                    "name": metric.name,
                    "value": metric.value,
                    "unit": metric.unit.description,
                    "metadata": metric.metadata ?? [:],
                ]
            }
        }

        if config.includeAlerts, !alerts.isEmpty {
            json["alerts"] = alerts.map { alert in
                [
                    "timestamp": formatDate(alert.timestamp),
                    "severity": String(describing: alert.severity),
                    "type": alert.type.localizedDescription,
                    "message": alert.message,
                    "context": alert.context,
                ]
            }
        }

        return try JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private func exportToPDF(
        report: PerformanceReport,
        alerts: [PerformanceAlert],
        config: ExportConfig
    ) throws -> Data {
        // In a real implementation, this would use PDFKit to generate a formatted PDF
        // For now, we'll return a simple text-based PDF
        let content = """
        Performance Report
        Period: \(formatDate(report.period.start)) - \(formatDate(report.period.end))

        Summary Statistics:
        - Average Operation Duration: \(report.statistics.averageOperationDuration) ms
        - Operation Success Rate: \(report.statistics.operationSuccessRate)%
        - Peak Memory Usage: \(formatBytes(report.statistics.peakMemoryUsage))
        - Average CPU Usage: \(report.statistics.averageCPUUsage)%
        - Peak CPU Usage: \(report.statistics.peakCPUUsage)%
        - Average Backup Speed: \(formatBytes(UInt64(report.statistics.averageBackupSpeed)))/s
        - Total Operations: \(report.statistics.totalOperations)
        - Failed Operations: \(report.statistics.failedOperations)
        """

        return content.data(using: .utf8) ?? Data()
    }

    private func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value > 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        return String(format: "%.2f %@", value, units[unitIndex])
    }
}
