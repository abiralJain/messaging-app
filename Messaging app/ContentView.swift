//
//  ContentView.swift
//  Messaging app
//
//  Created by Abiral Jain on 13/04/26.
//

import SwiftUI
import UIKit

// MARK: - ContentView

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
                        if isPinching { transaction.animation = nil }
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

    // MARK: - Background

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
                colors: [Color.white.opacity(0.78), Color.white.opacity(0)],
                center: .top,
                startRadius: 18,
                endRadius: 420
            )
            .blendMode(.screen)
        }
        .ignoresSafeArea()
    }

    // MARK: - Chrome

    @ViewBuilder
    private func topChrome(metrics: TimelineMetrics) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: metrics.safeAreaTop)

            HStack(spacing: 0) {
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(Color.accentColor)
                        Text("AJ")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 28, height: 28)

                    Text("Abiral Jain")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "video")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 4)

            Rectangle()
                .fill(Color(UIColor.separator).opacity(0.6))
                .frame(height: 0.33)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .opacity(metrics.chromeOpacity)
        .offset(y: metrics.topChromeOffset)
        .allowsHitTesting(metrics.chromeOpacity > 0.05)
    }

    @ViewBuilder
    private func bottomChrome(metrics: TimelineMetrics) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(UIColor.separator).opacity(0.6))
                .frame(height: 0.33)

            HStack(spacing: 8) {
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32, height: 32)
                        .background(Color.secondary.opacity(0.1), in: Circle())
                }

                ZStack {
                    Capsule(style: .continuous)
                        .fill(Color(UIColor.systemGray5))
                    HStack(spacing: 0) {
                        Text("iMessage")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Color(UIColor.placeholderText))
                            .padding(.leading, 12)
                        Spacer()
                    }
                }
                .frame(height: 34)

                Button(action: {}) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Color.clear
                .frame(height: metrics.safeAreaBottom)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .opacity(metrics.chromeOpacity)
        .offset(y: metrics.bottomChromeOffset)
        .allowsHitTesting(metrics.chromeOpacity > 0.05)
    }

    // MARK: - Gesture

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
                let target: CGFloat = pinchProgress > 0.5 ? 1 : 0
                let dayToPreserve = focusedDayGroup
                handleModeThresholdCrossing(for: target)
                baseProgress = target
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    pinchProgress = target
                    proxy.scrollTo(dayToPreserve, anchor: .center)
                }
            }
    }

    // MARK: - Focus Tracking

    private func updateFocusedDay(using viewport: ScrollViewport, metrics: TimelineMetrics) {
        guard viewport.containerHeight > 0 else { return }
        let visibleCenterY = viewport.offsetY + (viewport.containerHeight * 0.5)
        let midpoints = daySections.dayMidpoints(metrics: metrics)
        guard let nearest = midpoints.min(by: {
            abs($0.midY - visibleCenterY) < abs($1.midY - visibleCenterY)
        }) else { return }
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

// MARK: - DaySectionView

private struct DaySectionView: View {
    let day: ChatDaySection
    let dayIndex: Int
    let metrics: TimelineMetrics
    let isFocused: Bool

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Date separator pill
                Text(day.id)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12), in: Capsule(style: .continuous))
                    .frame(maxWidth: .infinity)
                    .frame(height: metrics.dateSeparatorPillHeight)
                    .opacity(1 - metrics.easedProgress)
                    .clipped()
                    .padding(.bottom, metrics.dateSeparatorPillHeight > 1 ? 8 : 0)

                ForEach(Array(day.messages.enumerated()), id: \.element.id) { index, message in
                    // Time separator for gaps > 1 hour within a day
                    if index > 0 {
                        let gap = message.timestamp.timeIntervalSince(day.messages[index - 1].timestamp)
                        if gap > 3600 {
                            Text(DaySectionView.timeFormatter.string(from: message.timestamp))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity)
                                .frame(height: metrics.timeSeparatorHeight)
                                .opacity(metrics.textOpacity)
                                .clipped()
                        }
                    }

                    MessageBubbleRow(message: message, metrics: metrics)
                        .padding(.bottom, bottomPadding(for: index, in: day.messages))
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

    private func bottomPadding(for index: Int, in messages: [ChatMessage]) -> CGFloat {
        guard index < messages.count - 1 else { return 0 }
        let current = messages[index]
        let next = messages[index + 1]
        if current.isSent != next.isSent {
            return metrics.interClusterSpacing
        }
        return metrics.intraDayMessageSpacing
    }
}

// MARK: - MessageBubbleRow

private struct MessageBubbleRow: View {
    let message: ChatMessage
    let metrics: TimelineMetrics

    var body: some View {
        let (width, height) = metrics.bubbleSize(for: message)
        let radius = metrics.bubbleCornerRadius(height: height)
        let isSent = message.isSent
        let tint = isSent ? messageBlue : receivedWarmGray
        let fgColor: Color = isSent ? .white : .primary
        let tailStrength = message.isLastInCluster ? (1 - metrics.easedProgress) : CGFloat(0)
        // Extra space below the bubble so the 6pt-tall tail is never clipped
        let tailPad: CGFloat = message.isLastInCluster ? 7 * (1 - metrics.easedProgress) : 0

        HStack(spacing: 0) {
            if isSent { Spacer(minLength: 0) }

            ZStack(alignment: isSent ? .topTrailing : .topLeading) {
                BubbleShape(
                    direction: isSent ? .sent : .received,
                    tailStrength: tailStrength,
                    cornerRadius: radius
                )
                .fill(tint)
                .frame(width: width, height: height)
                .opacity(isSent ? 1 : metrics.receivedBubbleOpacity)
                .overlay(
                    BubbleShape(
                        direction: isSent ? .sent : .received,
                        tailStrength: tailStrength,
                        cornerRadius: radius
                    )
                    .stroke(Color.white.opacity(isSent ? 0.08 : 0.22), lineWidth: 0.8)
                )

                Text(message.text)
                    .font(.body)
                    .lineLimit(nil)
                    .foregroundStyle(fgColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(width: width, height: height,
                           alignment: isSent ? .trailing : .leading)
                    .opacity(metrics.textOpacity)
                    .allowsHitTesting(false)
            }
            .frame(width: width, height: height + tailPad)

            if !isSent { Spacer(minLength: 0) }
        }
        .frame(width: metrics.messageColumnWidth)
    }
}

// MARK: - BubbleShape

private enum BubbleDirection { case sent, received }

private struct BubbleShape: Shape {
    let direction: BubbleDirection
    var tailStrength: CGFloat
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = Swift.min(Swift.min(cornerRadius, rect.height / 2), rect.width / 2)
        let ts = tailStrength

        guard ts > 0.005 else {
            return RoundedRectangle(cornerRadius: r, style: .continuous).path(in: rect)
        }

        let tx = CGFloat(8) * ts
        let ty = CGFloat(6) * ts

        var p = Path()

        switch direction {
        case .sent:
            // Clockwise from top-left
            p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + r),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            // Right edge, stop near bottom for tail exit
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r * lerp(0.5, 1.0, 1 - ts)))
            // Tail exit: curve to tip
            p.addCurve(
                to: CGPoint(x: rect.maxX + tx, y: rect.maxY + ty),
                control1: CGPoint(x: rect.maxX, y: rect.maxY + ty * 0.05),
                control2: CGPoint(x: rect.maxX + tx * 0.9, y: rect.maxY + ty * 0.45)
            )
            // Tail return: concave scoop back to bubble bottom
            p.addCurve(
                to: CGPoint(x: rect.maxX - ts * 3, y: rect.maxY),
                control1: CGPoint(x: rect.maxX + tx * 0.15, y: rect.maxY + ty * 1.2),
                control2: CGPoint(x: rect.maxX + tx * 0.02, y: rect.maxY + ty * 0.55)
            )
            p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            p.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - r),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            p.addQuadCurve(
                to: CGPoint(x: rect.minX + r, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )

        case .received:
            // Clockwise from top-left
            p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + r),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            // Bottom edge, stop near bottom-left for tail exit
            p.addLine(to: CGPoint(x: rect.minX + ts * 3, y: rect.maxY))
            // Tail exit: curve to tip (going left)
            p.addCurve(
                to: CGPoint(x: rect.minX - tx, y: rect.maxY + ty),
                control1: CGPoint(x: rect.minX - tx * 0.02, y: rect.maxY + ty * 0.55),
                control2: CGPoint(x: rect.minX - tx * 0.15, y: rect.maxY + ty * 1.2)
            )
            // Tail return: concave scoop back up to left edge
            p.addCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - r * lerp(0.5, 1.0, 1 - ts)),
                control1: CGPoint(x: rect.minX - tx * 0.9, y: rect.maxY + ty * 0.45),
                control2: CGPoint(x: rect.minX, y: rect.maxY + ty * 0.05)
            )
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
            p.addQuadCurve(
                to: CGPoint(x: rect.minX + r, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        }

        p.closeSubpath()
        return p
    }
}

// MARK: - DateSidebar

private struct DateSidebar: View {
    let day: ChatDaySection
    let dayIndex: Int
    let metrics: TimelineMetrics
    let isFocused: Bool

    var body: some View {
        let labelOpacity = metrics.dateLabelOpacity(for: dayIndex)
        let labelOffset = metrics.dateLabelOffset(for: dayIndex)

        HStack(spacing: 8) {
            Text(day.id)
                .font(.system(size: 15, weight: isFocused ? .bold : .regular))
                .foregroundStyle(isFocused ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize()

            if isFocused {
                Rectangle()
                    .fill(Color.primary)
                    .frame(width: metrics.focusBarWidth, height: 3)
                    .opacity(metrics.focusBarOpacity)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(densityBarWidths.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color(UIColor.systemGray4))
                            .frame(width: densityBarWidths[index], height: 3)
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
            return [14 + base, 20 + base * 0.72, 12 + base * 0.56]
        }
        return [13 + base, 18 + base * 0.68]
    }
}

// MARK: - TimelineMetrics

private struct TimelineMetrics {
    let progress: CGFloat
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets

    var easedProgress: CGFloat { smoothstep(progress) }

    var horizontalPadding: CGFloat { 16 }

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
        lerp(3, 1.5, easedProgress)
    }

    var interClusterSpacing: CGFloat {
        lerp(10, 2, easedProgress)
    }

    var dayGroupSpacing: CGFloat {
        lerp(16, 28, easedProgress)
    }

    var receivedBubbleOpacity: Double {
        Double(lerp(1, 0.5, progress))
    }

    var textOpacity: Double {
        Double(1 - delayedProgress(progress, start: 0.0, end: 0.22))
    }

    var chromeOpacity: Double {
        Double(1 - delayedProgress(progress, start: 0, end: 0.25))
    }

    var focusBarWidth: CGFloat {
        lerp(0, 40, easedProgress)
    }

    var focusBarOpacity: Double {
        Double(delayedProgress(progress, start: 0.40, end: 0.85))
    }

    var contentTopPadding: CGFloat {
        lerp(safeAreaInsets.top + 52, safeAreaInsets.top + 12, easedProgress)
    }

    var contentBottomPadding: CGFloat {
        lerp(safeAreaInsets.bottom + 54, safeAreaInsets.bottom + 16, easedProgress)
    }

    var safeAreaTop: CGFloat { safeAreaInsets.top }
    var safeAreaBottom: CGFloat { safeAreaInsets.bottom }

    var bottomAnchorSpacing: CGFloat { lerp(12, 0, easedProgress) }

    var topChromeOffset: CGFloat {
        lerp(0, -10, delayedProgress(progress, start: 0, end: 0.25))
    }

    var bottomChromeOffset: CGFloat {
        lerp(0, 12, delayedProgress(progress, start: 0, end: 0.25))
    }

    var dateSeparatorPillHeight: CGFloat {
        lerp(30, 0, easedProgress)
    }

    var timeSeparatorHeight: CGFloat {
        lerp(24, 0, easedProgress)
    }

    var shouldAnimateFocus: Bool { progress >= 0.82 }

    func expandedBubbleSize(for message: ChatMessage) -> (width: CGFloat, height: CGFloat) {
        let maxBubbleWidth = availableWidth * 0.75
        let hPad: CGFloat = 24 // 12pt left + 12pt right
        let vPad: CGFloat = 16 // 8pt top + 8pt bottom
        let font = UIFont.preferredFont(forTextStyle: .body)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let singleLineWidth = (message.text as NSString).size(withAttributes: attrs).width
        if singleLineWidth + hPad <= maxBubbleWidth {
            return (
                width: Swift.max(singleLineWidth + hPad, 44),
                height: ceil(font.lineHeight) + vPad
            )
        } else {
            let innerWidth = maxBubbleWidth - hPad
            let boundingRect = (message.text as NSString).boundingRect(
                with: CGSize(width: innerWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
            return (
                width: maxBubbleWidth,
                height: ceil(boundingRect.height) + vPad
            )
        }
    }

    func compressedBubbleHeight(for message: ChatMessage) -> CGFloat {
        let (expandedW, _) = expandedBubbleSize(for: message)
        let widthRatio = clamp01((expandedW - 44) / (availableWidth * 0.75 - 44))
        return lerp(6, 10, widthRatio)
    }

    func bubbleSize(for message: ChatMessage) -> (width: CGFloat, height: CGFloat) {
        let exp = expandedBubbleSize(for: message)
        let compH = compressedBubbleHeight(for: message)
        let compW = exp.width * 0.42
        let rawW = lerp(exp.width, compW, easedProgress)
        let minW = lerp(44, 20, easedProgress)
        let maxW = Swift.max(messageColumnWidth - 4, minW)
        let width = Swift.min(Swift.max(rawW, minW), maxW)
        let height = lerp(exp.height, compH, easedProgress)
        return (width, height)
    }

    func bubbleHeight(for message: ChatMessage) -> CGFloat {
        bubbleSize(for: message).height
    }

    func bubbleCornerRadius(height: CGFloat) -> CGFloat {
        Swift.min(lerp(18, height / 2, easedProgress), height / 2)
    }

    func bubbleWidth(for message: ChatMessage) -> CGFloat {
        bubbleSize(for: message).width
    }

    func dateLabelOpacity(for index: Int) -> Double {
        let start = 0.30 + (CGFloat(index) * 0.04)
        let end = Swift.min(0.82 + (CGFloat(index) * 0.04), 0.95)
        return Double(delayedProgress(progress, start: start, end: end))
    }

    func dateLabelOffset(for index: Int) -> CGFloat {
        lerp(16, 0, CGFloat(dateLabelOpacity(for: index)))
    }
}

// MARK: - ChatMessage

struct ChatMessage: Identifiable {
    let id: Int
    let isSent: Bool
    let text: String
    let timestamp: Date
    let dayGroup: String
    var isLastInCluster: Bool = true

    var widthFraction: CGFloat {
        let c = Double(text.count)
        return CGFloat(Swift.max(0.25, Swift.min(0.80, (c * 9.5 + 24) / 310.0)))
    }
}

// MARK: - ChatDaySection

private struct ChatDaySection: Identifiable {
    let id: String
    let messages: [ChatMessage]

    static let sample: [ChatDaySection] = {
        func makeDate(month: Int, day: Int, hour: Int, minute: Int) -> Date {
            var c = DateComponents()
            c.year = 2025; c.month = month; c.day = day
            c.hour = hour; c.minute = minute
            return Calendar.current.date(from: c) ?? Date.distantPast
        }

        typealias RawMsg = (Bool, String, Int, Int)

        let rawDays: [(Int, Int, String, [RawMsg])] = [
            (5, 25, "May 25", [
                (false, "yo what are you up to this weekend", 11, 2),
                (true,  "nothing much honestly, maybe gym then just chill", 11, 15),
                (false, "wanna grab brunch tomorrow? that new place on hill st", 11, 17),
                (true,  "the one with the shakshuka? I've been wanting to try that", 11, 19),
                (false, "yes!! heard it's insane, opens at 10", 11, 21),
                (true,  "let's do 11, I'm slow in the mornings lol", 11, 22),
                (false, "bet, see you there", 11, 24),
                (true,  "👍", 11, 25)
            ]),
            (5, 26, "May 26", [
                (false, "brunch was so good omg", 14, 33),
                (true,  "that shakshuka destroyed me in the best way possible", 14, 41),
                (false, "we have to go back", 14, 43)
            ]),
            (5, 28, "May 28", [
                (true,  "bro this day has been a nightmare", 16, 4),
                (false, "what happened", 16, 8),
                (true,  "client completely changed the brief at 4pm, presentation is tomorrow morning", 16, 9),
                (false, "oh no", 16, 11),
                (true,  "yeah I've been at my desk for 8 hours straight and now I have to redo everything", 16, 12),
                (false, "that's awful. do you need help with anything", 16, 15),
                (true,  "not really, just need to vent lol. this client is the worst", 16, 16),
                (false, "want me to bring you coffee? I'm near your office area", 16, 18),
                (true,  "oh my god yes please, oat flat white", 16, 19),
                (false, "omw", 16, 21),
                (true,  "you're a lifesaver", 16, 22),
                (false, "I got you a croissant too, you need to eat", 17, 45)
            ]),
            (5, 29, "May 29", [
                (true,  "presentation went well actually!! client loved it", 10, 30),
                (false, "WAIT seriously??", 10, 35),
                (true,  "yeah they said it was exactly what they wanted. sometimes the last minute panic is worth it", 10, 37),
                (false, "that's wild. you deserve a drink tonight", 10, 39),
                (true,  "100%", 10, 40)
            ]),
            (5, 30, "May 30", [
                (false, "ok so friday night plans. what are we thinking", 13, 22),
                (true,  "I was looking at that izakaya on Oak, have you been?", 13, 30),
                (false, "no but I've walked past it. it looks good", 13, 32),
                (true,  "the sake selection is apparently insane", 13, 33),
                (false, "sold. what time?", 13, 35),
                (true,  "7:30? We can get drinks first at that rooftop bar nearby", 13, 36),
                (false, "the one with the views?", 13, 38),
                (true,  "yeah, it's been too long since we've done a proper night out", 13, 39),
                (false, "I know right. should we see if Priya wants to come", 13, 41),
                (true,  "yeah text her, the more the merrier", 13, 42),
                (false, "she's in!! she's bringing her friend too who just moved to the city", 13, 55),
                (true,  "perfect. ok 6pm at the rooftop, 7:30 at the izakaya?", 13, 57),
                (false, "sorted. also wear something nice, I don't want to be the only one who made an effort", 14, 1),
                (true,  "lol when do I not make an effort", 14, 3),
                (false, "last time you showed up in a hoodie", 14, 4)
            ]),
            (5, 31, "May 31", [
                (true,  "running 20 mins late, so sorry", 17, 42),
                (false, "classic. I'm already here with drinks", 17, 44),
                (true,  "order me something good", 17, 45),
                (false, "already did", 17, 46),
                (true,  "ok you're forgiven", 17, 47),
                (false, "hurry up the view is actually stunning tonight", 17, 48),
                (true,  "omw omw", 17, 50),
                (false, "this sake is incredible", 19, 14),
                (true,  "right? I'm already on my second", 19, 16),
                (false, "Priya and her friend are hilarious btw", 19, 20),
                (true,  "I know, I'm obsessed with them already", 19, 22),
                (false, "we should all do a trip", 19, 24),
                (true,  "don't say that unless you mean it", 19, 25),
                (false, "I completely mean it, somewhere warm", 19, 26),
                (true,  "I'm looking up flights right now", 19, 28),
                (false, "same honestly", 19, 29),
                (true,  "ok we're doing this", 19, 31),
                (false, "next conversation: trip planning mode activated", 19, 33),
                (true,  "tonight was so fun", 23, 12),
                (false, "one of the best in a while", 23, 18)
            ]),
            (6, 1, "Jun 1", [
                (false, "I am destroyed today", 12, 3),
                (true,  "same, woke up at noon", 12, 15),
                (false, "worth it though", 12, 17),
                (true,  "completely", 12, 18)
            ]),
            (6, 3, "Jun 3", [
                (true,  "have you watched The Bear?", 20, 14),
                (false, "yes!!! obsessed", 20, 20),
                (true,  "I finally started it last night and watched 4 episodes in a row", 20, 21),
                (false, "that's how everyone starts. it's so stressful but so good", 20, 23),
                (true,  "the kitchen scenes give me anxiety in the best way", 20, 25),
                (false, "wait until you get to the long episode", 20, 26),
                (true,  "don't spoil it for me", 20, 28)
            ]),
            (6, 4, "Jun 4", [
                (false, "how far are you in The Bear", 15, 44),
                (true,  "just finished season 2, I need to take a day to process", 15, 52)
            ]),
            (6, 5, "Jun 5", [
                (true,  "ok next recommendation needed. movie this time", 18, 33),
                (false, "genre?", 18, 40),
                (true,  "anything, just make it good", 18, 41),
                (false, "Aftersun. watch it alone, lights off", 18, 43),
                (true,  "I've heard about that one", 18, 44),
                (false, "it'll stay with you for days. I'm not kidding", 18, 46),
                (true,  "that's either a great sign or a terrible one", 18, 47),
                (false, "both", 18, 48),
                (true,  "ok adding it to the list", 18, 50),
                (false, "report back immediately after", 18, 51)
            ]),
            (6, 6, "Jun 6", [
                (false, "have you tried that new ramen place on 5th?", 11, 22),
                (true,  "the one that opened like 2 weeks ago?", 11, 28),
                (false, "yeah. I walked past and the queue was insane", 11, 29),
                (true,  "queue at a ramen place is always a good sign", 11, 31),
                (false, "should we try it for lunch tomorrow?", 11, 33),
                (true,  "yes, what time does it open?", 11, 34),
                (false, "11am I think", 11, 35),
                (true,  "let's get there at 10:50 to beat the queue", 11, 36),
                (false, "you and your logistics", 11, 37),
                (true,  "someone has to plan things", 11, 38),
                (false, "fair enough", 11, 39),
                (true,  "also there's this dumpling spot nearby we could go after if we're still hungry", 11, 41),
                (false, "are we doing a food crawl now", 11, 42),
                (true,  "is that a problem", 11, 43),
                (false, "absolutely not", 11, 44),
                (true,  "ok so ramen then dumplings then maybe boba", 11, 46),
                (false, "I love how our hangouts always revolve around food", 11, 48),
                (true,  "what else would they revolve around", 11, 49)
            ]),
            (6, 7, "Jun 7", [
                (false, "ramen was worth the queue by the way", 14, 22),
                (true,  "the tonkotsu broth was perfect", 14, 28),
                (false, "and that soft boiled egg??", 14, 29),
                (true,  "I'm still thinking about it", 14, 31),
                (false, "we're going back", 14, 32),
                (true,  "every saturday from now on", 14, 33)
            ]),
            (6, 8, "Jun 8", [
                (true,  "watched Aftersun last night", 22, 14),
                (false, "...", 22, 22),
                (true,  "I need to sit with that for a while. you were right", 22, 24)
            ]),
            (6, 9, "Jun 9", [
                (false, "I saw this wild thing in the news today", 9, 15),
                (true,  "what", 9, 22),
                (false, "that tech company that laid off 2000 people and then said 'our people are our biggest asset'", 9, 23),
                (true,  "companies always say that right before doing the most unhinged things", 9, 25),
                (false, "the audacity is genuinely impressive", 9, 26),
                (true,  "at this point I've just accepted corporate speak is its own language", 9, 28),
                (false, "a language I did not consent to learn", 9, 29),
                (true,  "same", 9, 30)
            ]),
            (6, 10, "Jun 10", [
                (true,  "ok I have a random question", 20, 4),
                (false, "shoot", 20, 9),
                (true,  "do you think we'd still be friends if we met now vs when we were 19", 20, 10),
                (false, "that's a dangerous question", 20, 14),
                (true,  "I know but genuinely think about it", 20, 15),
                (false, "I think yes. maybe it would take longer", 20, 18),
                (true,  "why longer?", 20, 19),
                (false, "we're more guarded now. you take longer to trust people", 20, 21),
                (true,  "that's... actually true", 20, 22),
                (false, "but the core thing we both have is the same. we both actually show up for people", 20, 25),
                (true,  "that's really nice to say", 20, 27),
                (false, "don't get emotional on me", 20, 28)
            ]),
            (6, 11, "Jun 11", [
                (false, "hey can I ask you something", 16, 33),
                (true,  "always", 16, 40),
                (false, "do you think I should take the job offer", 16, 41),
                (true,  "I think the fact that you're asking means you already know what you want", 16, 45),
                (false, "yeah", 16, 47)
            ]),
            (6, 12, "Jun 12", [
                (true,  "how's the apartment search going", 11, 12),
                (false, "honestly terrible. everything is either too far or too expensive", 11, 20),
                (true,  "what's your budget again", 11, 21),
                (false, "I really don't want to go above 2k", 11, 22),
                (true,  "that's tight but doable in the right neighborhoods", 11, 24),
                (false, "I saw a place yesterday in Noe Valley but it was on the 4th floor with no elevator", 11, 26),
                (true,  "how are you with stairs", 11, 27),
                (false, "four flights every day would break me", 11, 28),
                (true,  "lol valid. have you tried that app Zumper?", 11, 30),
                (false, "I've been checking it constantly", 11, 31),
                (true,  "the market is genuinely insane right now", 11, 33),
                (false, "I know. my lease is up in 6 weeks which is not helping my anxiety", 11, 35),
                (true,  "you'll find something. and if you need a couch while you figure it out, you know where I am", 11, 37),
                (false, "you'd really let me crash?", 11, 39),
                (true,  "we'd survive. probably", 11, 40),
                (false, "haha I love you", 11, 41)
            ]),
            (6, 13, "Jun 13", [
                (false, "TGIF oh my god", 9, 2),
                (true,  "the week felt so long", 9, 8),
                (false, "same. ok plans tonight?", 9, 9),
                (true,  "I was thinking low key honestly", 9, 11),
                (false, "movie night?", 9, 12),
                (true,  "yes finally, I have been meaning to rewatch Parasite", 9, 13),
                (false, "iconic choice", 9, 14),
                (true,  "come over at like 7?", 9, 15),
                (false, "I'll bring snacks", 9, 16),
                (true,  "get those chili lime chips if you see them", 9, 17),
                (false, "obviously", 9, 18),
                (true,  "also can we order Thai", 9, 19),
                (false, "yes. green curry", 9, 20),
                (true,  "and pad see ew", 9, 21),
                (false, "done. I'm already excited", 9, 22),
                (true,  "it's the little things", 9, 23),
                (false, "genuinely. ok I have to survive the rest of the workday first", 9, 25),
                (true,  "you've got this", 9, 26),
                (false, "barely", 9, 27),
                (true,  "lol", 9, 28),
                (false, "ok heading out now, see you at 7", 18, 11),
                (true,  "🎉", 18, 15)
            ]),
            (6, 14, "Yesterday", [
                (false, "I'm still thinking about that movie", 10, 22),
                (true,  "the ending hits different every time", 10, 30),
                (false, "also that Thai food was really good", 10, 32),
                (true,  "yeah we're ordering from there again", 10, 33),
                (false, "agreed. hey are you doing anything this afternoon", 14, 15),
                (true,  "nothing planned, why", 14, 22),
                (false, "there's a farmers market at the park if you want to walk around", 14, 24),
                (true,  "I'm in. give me 30 mins", 14, 26),
                (false, "perfect", 14, 27)
            ]),
            (6, 15, "Today", [
                (true,  "morning! good sleep?", 9, 5),
                (false, "honestly the best sleep I've had in weeks", 9, 14),
                (true,  "the exhaustion from being social does that", 9, 16),
                (false, "facts. ok random thought — we should actually plan that trip we talked about", 9, 18),
                (true,  "I've been waiting for you to bring this up", 9, 20),
                (false, "Japan?", 9, 21),
                (true,  "Japan.", 9, 21),
                (false, "October could work?", 9, 23),
                (true,  "I'll check my calendar but I think I'm free the second half", 9, 24),
                (false, "me too probably. let's actually do it this time", 9, 26),
                (true,  "I'm looking at flights right now lol", 9, 27),
                (false, "ok this is actually happening", 9, 29)
            ])
        ]

        var nextID = 0
        var allMessages: [ChatMessage] = []

        for (month, day, label, rawMsgs) in rawDays {
            for (isSent, text, hour, minute) in rawMsgs {
                allMessages.append(ChatMessage(
                    id: nextID,
                    isSent: isSent,
                    text: text,
                    timestamp: makeDate(month: month, day: day, hour: hour, minute: minute),
                    dayGroup: label
                ))
                nextID += 1
            }
        }

        // Pre-compute isLastInCluster
        for i in 0..<allMessages.count - 1 {
            let curr = allMessages[i]
            let next = allMessages[i + 1]
            if curr.dayGroup == next.dayGroup && curr.isSent == next.isSent {
                allMessages[i].isLastInCluster = false
            }
        }

        let dayLabels = rawDays.map { $0.2 }
        return dayLabels.map { label in
            ChatDaySection(
                id: label,
                messages: allMessages.filter { $0.dayGroup == label }
            )
        }
    }()
}

// MARK: - Helper Types

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

// MARK: - dayMidpoints Extension

private extension Array where Element == ChatDaySection {
    func dayMidpoints(metrics: TimelineMetrics) -> [DayMidpoint] {
        var runningY = metrics.contentTopPadding
        var points: [DayMidpoint] = []

        for (index, day) in enumerated() {
            let pillHeight = metrics.dateSeparatorPillHeight + (metrics.dateSeparatorPillHeight > 1 ? 8 : 0)
            let messageHeights = day.messages.map { metrics.bubbleHeight(for: $0) }.reduce(0, +)
            let avgSpacing = (metrics.interClusterSpacing + metrics.intraDayMessageSpacing) / 2
            let internalSpacing = CGFloat(Swift.max(day.messages.count - 1, 0)) * avgSpacing
            let totalHeight = pillHeight + messageHeights + internalSpacing

            points.append(DayMidpoint(dayID: day.id, midY: runningY + totalHeight * 0.5))
            runningY += totalHeight
            if index < count - 1 { runningY += metrics.dayGroupSpacing }
        }

        return points
    }
}

// MARK: - Glass Chrome

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

// MARK: - Constants & Helpers

private let messageBlue = Color(red: 0, green: 0.478, blue: 1)
private let receivedWarmGray = Color(red: 0.91, green: 0.90, blue: 0.88)

private func clamp01(_ value: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, 0), 1)
}

private func lerp(_ start: CGFloat, _ end: CGFloat, _ t: CGFloat) -> CGFloat {
    start + (end - start) * clamp01(t)
}

private func smoothstep(_ t: CGFloat) -> CGFloat {
    let c = clamp01(t)
    return c * c * (3 - 2 * c)
}

private func delayedProgress(_ progress: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
    smoothstep(clamp01((progress - start) / Swift.max(end - start, 0.001)))
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
