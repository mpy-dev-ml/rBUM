import Charts
import SwiftUI

/// View for visualising performance metrics
public struct PerformanceVisualisationView: View {
    private let report: PerformanceReport
    private let alerts: [PerformanceAlert]
    
    public init(report: PerformanceReport, alerts: [PerformanceAlert] = []) {
        self.report = report
        self.alerts = alerts
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summarySection
                
                if !alerts.isEmpty {
                    alertsSection
                }
                
                resourceUsageCharts
                operationMetricsCharts
            }
            .padding()
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Performance Summary")
                .font(.headline)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Success Rate:")
                    Text("\(report.statistics.operationSuccessRate, specifier: "%.1f")%")
                        .foregroundColor(successRateColor)
                }
                GridRow {
                    Text("Average Duration:")
                    Text("\(report.statistics.averageOperationDuration, specifier: "%.0f")ms")
                }
                GridRow {
                    Text("Total Operations:")
                    Text("\(report.statistics.totalOperations)")
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Active Alerts")
                .font(.headline)
            
            ForEach(alerts) { alert in
                HStack {
                    Circle()
                        .fill(alert.severity == .critical ? Color.red : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading) {
                        Text(alert.type.localizedDescription)
                            .font(.subheadline)
                            .bold()
                        Text(alert.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var resourceUsageCharts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resource Usage")
                .font(.headline)
            
            Chart {
                ForEach(
                    report.metrics.filter { 
                        $0.unit == .percentage && 
                        $0.name == "cpu_usage" 
                    },
                    id: \.timestamp
                ) { metric in
                    LineMark(
                        x: .value("Time", metric.timestamp),
                        y: .value("CPU", metric.value)
                    )
                    .foregroundStyle(Color.blue)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            
            Chart {
                ForEach(
                    report.metrics.filter { 
                        $0.unit == .bytes && 
                        $0.name == "memory_usage" 
                    },
                    id: \.timestamp
                ) { metric in
                    LineMark(
                        x: .value("Time", metric.timestamp),
                        y: .value("Memory", Double(metric.value) / 1024 / 1024) // Convert to MB
                    )
                    .foregroundStyle(Color.green)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var operationMetricsCharts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Operation Metrics")
                .font(.headline)
            
            Chart {
                ForEach(
                    report.metrics.filter { 
                        $0.unit == .bytesPerSecond && 
                        $0.name == "backup_speed" 
                    },
                    id: \.timestamp
                ) { metric in
                    LineMark(
                        x: .value("Time", metric.timestamp),
                        y: .value("Speed", Double(metric.value) / 1024 / 1024) // Convert to MB/s
                    )
                    .foregroundStyle(Color.purple)
                }
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var successRateColor: Color {
        switch report.statistics.operationSuccessRate {
        case 95...: return .green
        case 80...: return .yellow
        default: return .red
        }
    }
}
