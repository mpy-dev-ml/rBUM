import Charts
import SwiftUI

/// View for displaying operation duration distribution
public struct OperationDurationChart: View {
    private let operations: [MonitoredOperation]
    private let maxDuration: Double

    public init(operations: [MonitoredOperation]) {
        self.operations = operations
        maxDuration = operations.compactMap(\.duration).max() ?? 0
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Operation Durations")
                .font(.headline)

            Chart {
                ForEach(operations.filter { $0.duration != nil }, id: \.id) { operation in
                    BarMark(
                        x: .value("Operation", operation.name),
                        y: .value("Duration", operation.duration ?? 0)
                    )
                    .foregroundStyle(by: .value("Status", operation.status?.description ?? "Unknown"))
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
}

/// View for displaying resource usage heat map
public struct ResourceHeatMapView: View {
    private let metrics: [MetricMeasurement]
    private let columns: Int
    private let rows: Int

    public init(metrics: [MetricMeasurement], columns: Int = 24, rows: Int = 7) {
        self.metrics = metrics
        self.columns = columns
        self.rows = rows
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Resource Usage Heat Map")
                .font(.headline)

            let grid = createHeatMapGrid()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns)) {
                ForEach(0 ..< rows * columns, id: \.self) { index in
                    let value = grid[index]
                    Rectangle()
                        .fill(heatMapColor(for: value))
                        .frame(height: 20)
                        .overlay(
                            Text(String(format: "%.0f", value))
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                        )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private func createHeatMapGrid() -> [Double] {
        var grid = Array(repeating: 0.0, count: rows * columns)
        let now = Date()
        let calendar = Calendar.current

        for metric in metrics {
            if let hourDiff = calendar.dateComponents([.hour], from: metric.timestamp, to: now).hour,
               let dayDiff = calendar.dateComponents([.day], from: metric.timestamp, to: now).day
            {
                let column = hourDiff % columns
                let row = dayDiff % rows
                let index = row * columns + column
                if index >= 0, index < grid.count {
                    grid[index] = max(grid[index], metric.value)
                }
            }
        }

        return grid
    }

    private func heatMapColor(for value: Double) -> Color {
        let normalized = min(max(value / 100.0, 0.0), 1.0)
        return Color(
            red: normalized,
            green: 0.3,
            blue: 1.0 - normalized
        )
    }
}

/// View for displaying performance trends
public struct PerformanceTrendsView: View {
    private let report: PerformanceReport
    private let timeWindows: [(String, TimeInterval)] = [
        ("1h", 3600),
        ("6h", 21600),
        ("24h", 86400),
        ("7d", 604_800),
    ]

    @State private var selectedWindow: TimeInterval = 3600

    public init(report: PerformanceReport) {
        self.report = report
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Performance Trends")
                .font(.headline)

            Picker("Time Window", selection: $selectedWindow) {
                ForEach(timeWindows, id: \.1) { window in
                    Text(window.0).tag(window.1)
                }
            }
            .pickerStyle(.segmented)

            trendChart
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private var trendChart: some View {
        Chart {
            ForEach(filteredMetrics, id: \.timestamp) { metric in
                LineMark(
                    x: .value("Time", metric.timestamp),
                    y: .value("Value", metric.value)
                )
                .foregroundStyle(by: .value("Metric", metric.name))
            }
        }
        .frame(height: 200)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    private var filteredMetrics: [MetricMeasurement] {
        let cutoff = Date().addingTimeInterval(-selectedWindow)
        return report.metrics.filter { $0.timestamp > cutoff }
    }
}

/// View for displaying alert history
public struct AlertHistoryView: View {
    private let alerts: [PerformanceAlert]

    public init(alerts: [PerformanceAlert]) {
        self.alerts = alerts
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alert History")
                .font(.headline)

            ForEach(alerts.sorted { $0.timestamp > $1.timestamp }) { alert in
                AlertRow(alert: alert)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

private struct AlertRow: View {
    let alert: PerformanceAlert

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(alert.severity == .critical ? Color.red : Color.orange)
                    .frame(width: 8, height: 8)

                Text(alert.type.localizedDescription)
                    .font(.subheadline)
                    .bold()

                Spacer()

                Text(alert.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(alert.message)
                .font(.caption)
                .foregroundColor(.secondary)

            if !alert.context.isEmpty {
                ForEach(alert.context.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    Text("\(key): \(value)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
