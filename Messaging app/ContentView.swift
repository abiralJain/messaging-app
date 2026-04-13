//
//  ContentView.swift
//  Messaging app
//
//  Created by Abiral Jain on 13/04/26.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var pinchProgress: CGFloat = 0
    @State private var baseProgress: CGFloat = 0
    @State private var isPinching = false
    @State private var focusedDayGroup = ChatDaySection.sample.last?.id ?? ""
    @State private var viewport = ScrollViewport(offsetY: 0, containerHeight: 0)
    @State private var hasScrolledToBottom = false
    @State private var isPastModeThreshold = false

    private let daySections = ChatDaySection.sample
    private let bottomAnchorID = "conversation-bottom-anchor"

    var body: some View {
        GeometryReader { geometry in
            let metrics = TimelineMetrics(
                progress: pinchProgress,
                containerSize: geometry.size,
                safeAreaInsets: geometry.safeAreaInsets
            )

            ScrollViewReader { proxy in
                ZStack {
                    conversationBackground

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: metrics.dayGroupSpacing) {
                            ForEach(Array(daySections.enumerated()), id: \.element.id) { index, day in
                                DaySectionView(
                                    day: day,
                                    dayIndex: index,
                                    metrics: metrics,
                                    isFocused: focusedDayGroup == day.id
                                )
                                .id(day.id)
                            }

                            Color.clear
                                .frame(height: metrics.bottomAnchorSpacing)
                                .id(bottomAnchorID)
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, metrics.horizontalPadding)
                        .padding(.top, metrics.contentTopPadding)
                        .padding(.bottom, metrics.contentBottomPadding)
                        .contentShape(Rectangle())
                    }
                    .coordinateSpace(name: ScrollSpace.timeline)
                    .simultaneousGesture(pinchGesture(proxy: proxy))
                    .onScrollGeometryChange(for: ScrollViewport.self) { scrollGeometry in
                        ScrollViewport(
                            offsetY: Swift.max(scrollGeometry.contentOffset.y, 0),
                            containerHeight: scrollGeometry.containerSize.height
                        )
                    } action: { _, newViewport in
                        viewport = newViewport
                        updateFocusedDay(using: newViewport, metrics: metrics)
                    }
                    .onAppear {
                        guard !hasScrolledToBottom else { return }
                        hasScrolledToBottom = true

                        DispatchQueue.main.async {
                            var transaction = Transaction(animation: nil)
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: pinchProgress) { _, newValue in
                        handleModeThresholdCrossing(for: newValue)
                        updateFocusedDay(using: viewport, metrics: metrics)
                    }
                    .transaction { transaction in
                        if isPinching {
                            transaction.animation = nil
                        }
                    }

                    VStack(spacing: 0) {
                        topChrome(metrics: metrics)
                        Spacer()
                        bottomChrome(metrics: metrics)
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .preferredColorScheme(.light)
    }

    private var conversationBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.985, green: 0.982, blue: 0.975),
                    Color(red: 0.972, green: 0.968, blue: 0.959)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.78),
                    Color.white.opacity(0)
                ],
                center: .top,
                startRadius: 18,
                endRadius: 420
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func topChrome(metrics: TimelineMetrics) -> some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 36, height: 36)
            }
            .glassOrMaterial(in: Circle(), interactive: true)

            Spacer()

            Text("🐶")
                .font(.system(size: 22))
                .frame(width: 40, height: 40)
                .scaleEffect(metrics.avatarScale)
                .glassOrMaterial(in: Circle())

            Spacer()

            Button(action: {}) {
                Image(systemName: "video")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color.primary)
                    .frame(width: 36, height: 36)
            }
            .glassOrMaterial(in: Circle(), interactive: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, metrics.safeAreaTop + 6)
        .opacity(metrics.chromeOpacity)
        .offset(y: metrics.topChromeOffset)
        .allowsHitTesting(metrics.chromeOpacity > 0.05)
    }

    @ViewBuilder
    private func bottomChrome(metrics: TimelineMetrics) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .glassOrMaterial(in: Circle(), interactive: true)

            HStack {
                Text("iMessage")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
            .glassOrMaterial(in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.bottom, Swift.max(metrics.safeAreaBottom, 10))
        .opacity(metrics.chromeOpacity)
        .offset(y: metrics.bottomChromeOffset)
        .allowsHitTesting(metrics.chromeOpacity > 0.05)
    }

    private func pinchGesture(proxy: ScrollViewProxy) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.002)
            .onChanged { value in
                isPinching = true

                let rawScale = CGFloat(value.magnification)
                let delta = 1 - rawScale
                let nextProgress = clamp01(baseProgress + delta * 1.8)

                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    pinchProgress = nextProgress
                }
            }
            .onEnded { _ in
                isPinching = false

                let target: CGFloat = pinchProgress > 0.45 ? 1 : 0
                let dayToPreserve = focusedDayGroup

                handleModeThresholdCrossing(for: target)
                baseProgress = target

                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    pinchProgress = target
                    proxy.scrollTo(dayToPreserve, anchor: .center)
                }
            }
    }

    private func updateFocusedDay(using viewport: ScrollViewport, metrics: TimelineMetrics) {
        guard viewport.containerHeight > 0 else { return }

        let visibleCenterY = viewport.offsetY + (viewport.containerHeight * 0.5)
        let midpoints = daySections.dayMidpoints(metrics: metrics)

        guard let nearest = midpoints.min(by: {
            abs($0.midY - visibleCenterY) < abs($1.midY - visibleCenterY)
        }) else {
            return
        }

        guard nearest.dayID != focusedDayGroup else { return }

        if metrics.shouldAnimateFocus && !isPinching {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                focusedDayGroup = nearest.dayID
            }
            fireSelectionHaptic()
        } else {
            focusedDayGroup = nearest.dayID
        }
    }

    private func handleModeThresholdCrossing(for progress: CGFloat) {
        let newState = progress >= 0.5
        guard newState != isPastModeThreshold else { return }

        isPastModeThreshold = newState
        fireModeTransitionHaptic()
    }

    private func fireModeTransitionHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.9)
    }

    private func fireSelectionHaptic() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

private struct DaySectionView: View {
    let day: ChatDaySection
    let dayIndex: Int
    let metrics: TimelineMetrics
    let isFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(day.messages.enumerated()), id: \.element.id) { index, message in
                    MessageBubbleRow(
                        message: message,
                        metrics: metrics
                    )
                    .padding(.bottom, index == day.messages.count - 1 ? 0 : metrics.intraDayMessageSpacing)
                }
            }
            .frame(width: metrics.messageColumnWidth, alignment: .leading)

            DateSidebar(
                day: day,
                dayIndex: dayIndex,
                metrics: metrics,
                isFocused: isFocused
            )
            .frame(width: metrics.dateColumnWidth, alignment: .trailing)
        }
    }
}

private struct MessageBubbleRow: View {
    let message: ChatMessage
    let metrics: TimelineMetrics

    var body: some View {
        let height = metrics.bubbleHeight(for: message)
        let width = metrics.bubbleWidth(for: message)
        let radius = metrics.bubbleCornerRadius(for: message)

        HStack(spacing: 0) {
            if message.isSent {
                Spacer(minLength: 0)
            }

            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(message.isSent ? messageBlue : receivedWarmGray)
                .frame(width: width, height: height)
                .opacity(message.isSent ? 1 : metrics.receivedBubbleOpacity)
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.white.opacity(message.isSent ? 0.08 : 0.22), lineWidth: 0.8)
                }

            if !message.isSent {
                Spacer(minLength: 0)
            }
        }
        .frame(width: metrics.messageColumnWidth, alignment: .leading)
    }
}

private struct DateSidebar: View {
    let day: ChatDaySection
    let dayIndex: Int
    let metrics: TimelineMetrics
    let isFocused: Bool

    var body: some View {
        let labelOpacity = metrics.dateLabelOpacity(for: dayIndex)
        let labelOffset = metrics.dateLabelOffset(for: dayIndex)

        HStack(spacing: 10) {
            Text(day.id)
                .font(.system(size: 13, weight: isFocused ? .semibold : .regular))
                .foregroundStyle(isFocused ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if isFocused {
                Capsule(style: .continuous)
                    .fill(Color.primary)
                    .frame(width: metrics.focusBarWidth, height: 3)
                    .opacity(metrics.focusBarOpacity)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(densityBarWidths.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(Color(UIColor.systemGray4))
                            .frame(width: densityBarWidths[index], height: 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .opacity(labelOpacity)
        .offset(x: labelOffset)
    }

    private var densityBarWidths: [CGFloat] {
        let count = day.messages.count
        let base = CGFloat(count) * 1.9

        if count >= 6 {
            return [
                14 + base,
                20 + base * 0.72,
                12 + base * 0.56
            ]
        }

        return [
            13 + base,
            18 + base * 0.68
        ]
    }
}

private struct TimelineMetrics {
    let progress: CGFloat
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets

    var easedProgress: CGFloat {
        smoothstep(progress)
    }

    var horizontalPadding: CGFloat {
        16
    }

    var availableWidth: CGFloat {
        Swift.max(containerSize.width - (horizontalPadding * 2), 0)
    }

    var messageColumnWidth: CGFloat {
        lerp(availableWidth, availableWidth * 0.52, easedProgress)
    }

    var dateColumnWidth: CGFloat {
        Swift.max(availableWidth - messageColumnWidth, 0)
    }

    var intraDayMessageSpacing: CGFloat {
        lerp(10, 2, easedProgress)
    }

    var dayGroupSpacing: CGFloat {
        lerp(20, 6, easedProgress)
    }

    var receivedBubbleOpacity: Double {
        Double(lerp(1, 0.5, progress))
    }

    var chromeOpacity: Double {
        Double(1 - delayedProgress(progress, start: 0, end: 0.25))
    }

    var avatarScale: CGFloat {
        lerp(1, 0.6, easedProgress)
    }

    var focusBarWidth: CGFloat {
        lerp(0, 40, easedProgress)
    }

    var focusBarOpacity: Double {
        Double(delayedProgress(progress, start: 0.40, end: 0.85))
    }

    var contentTopPadding: CGFloat {
        lerp(safeAreaInsets.top + 60, safeAreaInsets.top + 12, easedProgress)
    }

    var contentBottomPadding: CGFloat {
        lerp(safeAreaInsets.bottom + 74, safeAreaInsets.bottom + 16, easedProgress)
    }

    var safeAreaTop: CGFloat {
        safeAreaInsets.top
    }

    var safeAreaBottom: CGFloat {
        safeAreaInsets.bottom
    }

    var bottomAnchorSpacing: CGFloat {
        lerp(12, 0, easedProgress)
    }

    var topChromeOffset: CGFloat {
        lerp(0, -10, delayedProgress(progress, start: 0, end: 0.25))
    }

    var bottomChromeOffset: CGFloat {
        lerp(0, 12, delayedProgress(progress, start: 0, end: 0.25))
    }

    var shouldAnimateFocus: Bool {
        progress >= 0.82
    }

    func expandedBubbleHeight(for message: ChatMessage) -> CGFloat {
        let normalizedWidth = clamp01((message.widthFraction - 0.25) / 0.60)
        return lerp(36, 44, normalizedWidth)
    }

    func compressedBubbleHeight(for message: ChatMessage) -> CGFloat {
        let normalizedWidth = clamp01((message.widthFraction - 0.25) / 0.60)
        return lerp(5, 8, normalizedWidth)
    }

    func bubbleHeight(for message: ChatMessage) -> CGFloat {
        lerp(expandedBubbleHeight(for: message), compressedBubbleHeight(for: message), easedProgress)
    }

    func bubbleCornerRadius(for message: ChatMessage) -> CGFloat {
        lerp(expandedBubbleHeight(for: message) / 2, 3, easedProgress)
    }

    func bubbleWidth(for message: ChatMessage) -> CGFloat {
        let expandedWidth = availableWidth * message.widthFraction
        let compressedWidth = expandedWidth * 0.42
        let rawWidth = lerp(expandedWidth, compressedWidth, easedProgress)
        let minimumWidth = lerp(72, 26, easedProgress)
        let maximumWidth = Swift.max(messageColumnWidth - 4, minimumWidth)
        return Swift.min(Swift.max(rawWidth, minimumWidth), maximumWidth)
    }

    func dateLabelOpacity(for index: Int) -> Double {
        let start = 0.30 + (CGFloat(index) * 0.02)
        let end = 0.80 + (CGFloat(index) * 0.02)
        return Double(delayedProgress(progress, start: start, end: end))
    }

    func dateLabelOffset(for index: Int) -> CGFloat {
        lerp(16, 0, CGFloat(dateLabelOpacity(for: index)))
    }
}

struct ChatMessage: Identifiable {
    let id: Int
    let isSent: Bool
    let widthFraction: CGFloat
    let dayGroup: String
}

private struct ChatDaySection: Identifiable {
    let id: String
    let messages: [ChatMessage]

    static let orderedDays = [
        "Jun 09",
        "Jun 10",
        "Jun 11",
        "Jun 12",
        "Jun 13",
        "Jun 14",
        "Jun 15",
        "Jun 16",
        "Yesterday",
        "Today"
    ]

    static let sample: [ChatDaySection] = {
        let specs: [(String, [(Bool, CGFloat)])] = [
            ("Jun 09", [(false, 0.32), (true, 0.56), (false, 0.74), (true, 0.48), (false, 0.27)]),
            ("Jun 10", [(true, 0.29), (false, 0.52), (true, 0.81), (false, 0.44), (true, 0.58), (true, 0.33)]),
            ("Jun 11", [(false, 0.71), (true, 0.37), (false, 0.49), (true, 0.76), (false, 0.28)]),
            ("Jun 12", [(true, 0.34), (false, 0.59), (true, 0.83), (false, 0.46), (true, 0.53), (false, 0.72), (false, 0.31)]),
            ("Jun 13", [(false, 0.43), (true, 0.66), (false, 0.26), (true, 0.78), (true, 0.52), (false, 0.36)]),
            ("Jun 14", [(true, 0.47), (false, 0.57), (true, 0.35), (false, 0.80), (true, 0.30)]),
            ("Jun 15", [(false, 0.28), (true, 0.62), (false, 0.75), (true, 0.41), (false, 0.55), (true, 0.84)]),
            ("Jun 16", [(true, 0.33), (false, 0.68), (true, 0.50), (false, 0.27), (false, 0.60), (true, 0.73), (false, 0.45)]),
            ("Yesterday", [(false, 0.54), (true, 0.31), (false, 0.79), (true, 0.63), (false, 0.38)]),
            ("Today", [(true, 0.27), (false, 0.48), (true, 0.70), (false, 0.34), (true, 0.57), (true, 0.82)])
        ]

        var nextID = 0
        let messages = specs.flatMap { day, entries in
            entries.map { entry -> ChatMessage in
                defer { nextID += 1 }
                return ChatMessage(
                    id: nextID,
                    isSent: entry.0,
                    widthFraction: entry.1,
                    dayGroup: day
                )
            }
        }

        return orderedDays.map { day in
            ChatDaySection(
                id: day,
                messages: messages.filter { $0.dayGroup == day }
            )
        }
    }()
}

private struct ScrollViewport: Equatable {
    let offsetY: CGFloat
    let containerHeight: CGFloat
}

private struct DayMidpoint: Equatable {
    let dayID: String
    let midY: CGFloat
}

private enum ScrollSpace {
    static let timeline = "timeline-scroll"
}

private extension Array where Element == ChatDaySection {
    func dayMidpoints(metrics: TimelineMetrics) -> [DayMidpoint] {
        var runningY = metrics.contentTopPadding
        var points: [DayMidpoint] = []

        for (index, day) in enumerated() {
            let messageHeights = day.messages.map { metrics.bubbleHeight(for: $0) }.reduce(0, +)
            let internalSpacing = CGFloat(Swift.max(day.messages.count - 1, 0)) * metrics.intraDayMessageSpacing
            let totalHeight = messageHeights + internalSpacing

            points.append(
                DayMidpoint(
                    dayID: day.id,
                    midY: runningY + (totalHeight * 0.5)
                )
            )

            runningY += totalHeight
            if index < count - 1 {
                runningY += metrics.dayGroupSpacing
            }
        }

        return points
    }
}

private struct GlassChromeModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                content.glassEffect(.regular.interactive(), in: shape)
            } else {
                content.glassEffect(.regular, in: shape)
            }
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

private extension View {
    func glassOrMaterial<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(GlassChromeModifier(shape: shape, interactive: interactive))
    }
}

private let messageBlue = Color(red: 0.204, green: 0.471, blue: 0.965)
private let receivedWarmGray = Color(red: 0.91, green: 0.90, blue: 0.88)

private func clamp01(_ value: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, 0), 1)
}

private func lerp(_ start: CGFloat, _ end: CGFloat, _ t: CGFloat) -> CGFloat {
    start + (end - start) * clamp01(t)
}

private func smoothstep(_ t: CGFloat) -> CGFloat {
    let clamped = clamp01(t)
    return clamped * clamped * (3 - (2 * clamped))
}

private func delayedProgress(_ progress: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
    smoothstep(clamp01((progress - start) / (end - start)))
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
