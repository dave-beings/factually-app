//
//  FactuallyWidget.swift
//  FactuallyWidget
//
//  Created by Dave Johnstone on 04/09/2025.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of one entry that refreshes daily
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate)
        entries.append(entry)

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct FactuallyWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        Link(destination: URL(string: "factually://start-recording")!) {
            VStack(spacing: 8) {
                // App Icon - using mic.circle to match the app's branding
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Text below icon
                Text("Tap to Fact Check")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
    }
}

struct FactuallyWidget: Widget {
    let kind: String = "FactuallyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                FactuallyWidgetEntryView(entry: entry)
                    .containerBackground(Color.black, for: .widget)
            } else {
                FactuallyWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color.black)
            }
        }
        .configurationDisplayName("Factually")
        .description("Quick access to fact-checking. Tap to start listening.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    FactuallyWidget()
} timeline: {
    SimpleEntry(date: .now)
}
