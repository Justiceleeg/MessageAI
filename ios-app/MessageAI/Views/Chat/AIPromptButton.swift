//
//  AIPromptButton.swift
//  MessageAI
//
//  AI suggestion button for events, reminders, decisions, etc.
//  Story 5.1 - Smart Calendar Extraction
//

import SwiftUI

/// A compact button for AI suggestions (for positioning next to timestamp)
struct AIPromptButtonCompact: View {
    let icon: String
    let text: String
    let tintColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(text)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(tintColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tintColor.opacity(0.5), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(tintColor.opacity(0.08))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// A button that displays AI suggestions below messages (e.g., "➕ Add to calendar?")
struct AIPromptButton: View {
    let icon: String
    let text: String
    let tintColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(text)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(tintColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tintColor.opacity(0.5), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(tintColor.opacity(0.08))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// Container for AI prompts that appear below message bubbles
/// Shows highest priority detection only (Invitation > Event > Reminder > Decision)
/// Compact version that sits next to timestamp
struct AIPromptContainerCompact: View {
    let analysis: MessageAnalysisResponse
    let onAddEvent: (CalendarDetection) -> Void
    let onAddReminder: (ReminderDetection) -> Void
    let onSaveDecision: (DecisionDetection) -> Void
    let onCreateInvitation: (InvitationDetection) -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // Priority 1: Invitation (Story 5.4) - now unified with calendar detection
            if analysis.calendar.detected && analysis.calendar.isInvitation {
                AIPromptButtonCompact(
                    icon: "party.popper.fill",
                    text: "Create event & invite",
                    tintColor: .purple
                ) {
                    // Create a mock InvitationDetection for backward compatibility
                    let mockInvitation = InvitationDetection(
                        detected: true,
                        type: "create",
                        eventTitle: analysis.calendar.title,
                        invitationDetected: true
                    )
                    onCreateInvitation(mockInvitation)
                }
            }
            // Priority 2: Calendar event (Story 5.1) - only if no invitation
            else if analysis.calendar.detected {
                AIPromptButtonCompact(
                    icon: "calendar.badge.plus",
                    text: "Add to calendar",
                    tintColor: .blue
                ) {
                    onAddEvent(analysis.calendar)
                }
            }
            // Priority 3: Reminder (Story 5.5) - only if no invitation or event
            else if analysis.reminder.detected {
                AIPromptButtonCompact(
                    icon: "bell.badge.fill",
                    text: "Set reminder",
                    tintColor: .orange
                ) {
                    onAddReminder(analysis.reminder)
                }
            }
            // Priority 4: Decision (Story 5.2) - only if no invitation, event, or reminder
            else if analysis.decision.detected {
                AIPromptButtonCompact(
                    icon: "checkmark.circle.fill",
                    text: "Save decision",
                    tintColor: .green
                ) {
                    onSaveDecision(analysis.decision)
                }
            }
            
            // Priority indicator (compact)
            if analysis.priority.detected, let level = analysis.priority.level {
                HStack(spacing: 2) {
                    Image(systemName: priorityIcon(for: level))
                        .font(.system(size: 9))
                    Text(level.prefix(1).uppercased()) // "H", "M", "L"
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(priorityColor(for: level))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(priorityColor(for: level).opacity(0.15))
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
    }
    
    // MARK: - Helper Functions
    
    private func priorityIcon(for level: String) -> String {
        switch level.lowercased() {
        case "high": return "exclamationmark.3"
        case "medium": return "exclamationmark.2"
        case "low": return "exclamationmark"
        default: return "exclamationmark"
        }
    }
    
    private func priorityColor(for level: String) -> Color {
        switch level.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .yellow
        default: return .gray
        }
    }
}

/// Container for AI prompts that appear below message bubbles
/// Shows highest priority detection only (Invitation > Event > Reminder > Decision)
struct AIPromptContainer: View {
    let analysis: MessageAnalysisResponse
    let onAddEvent: (CalendarDetection) -> Void
    let onAddReminder: (ReminderDetection) -> Void
    let onSaveDecision: (DecisionDetection) -> Void
    let onCreateInvitation: (InvitationDetection) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Priority 1: Invitation (Story 5.4) - now unified with calendar detection
            if analysis.calendar.detected && analysis.calendar.isInvitation {
                AIPromptButton(
                    icon: "party.popper.fill",
                    text: "🎉 Create event & invite?",
                    tintColor: .purple
                ) {
                    // Create a mock InvitationDetection for backward compatibility
                    let mockInvitation = InvitationDetection(
                        detected: true,
                        type: "create",
                        eventTitle: analysis.calendar.title,
                        invitationDetected: true
                    )
                    onCreateInvitation(mockInvitation)
                }
            }
            // Priority 2: Calendar event (Story 5.1) - only if no invitation
            else if analysis.calendar.detected {
                AIPromptButton(
                    icon: "calendar.badge.plus",
                    text: "Add to calendar?",
                    tintColor: .blue
                ) {
                    onAddEvent(analysis.calendar)
                }
            }
            // Priority 3: Reminder (Story 5.5) - only if no invitation or event
            else if analysis.reminder.detected {
                AIPromptButton(
                    icon: "bell.badge.fill",
                    text: "Set reminder?",
                    tintColor: .orange
                ) {
                    onAddReminder(analysis.reminder)
                }
            }
            // Priority 4: Decision (Story 5.2) - only if no invitation, event, or reminder
            else if analysis.decision.detected {
                AIPromptButton(
                    icon: "checkmark.circle.fill",
                    text: "Save decision?",
                    tintColor: .green
                ) {
                    onSaveDecision(analysis.decision)
                }
            }
            
            // Priority indicator (visual only, shown alongside any prompt)
            if analysis.priority.detected, let level = analysis.priority.level {
                HStack(spacing: 4) {
                    Image(systemName: priorityIcon(for: level))
                        .font(.system(size: 11))
                    Text("\(level.capitalized) priority")
                        .font(.system(size: 12))
                }
                .foregroundColor(priorityColor(for: level))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(priorityColor(for: level).opacity(0.1))
                )
            }
            
            // Conflict warning (visual only, shown alongside any prompt)
            if analysis.conflict.detected && !analysis.conflict.conflictingEvents.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text("Schedule conflict detected")
                        .font(.system(size: 12))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                )
            }
        }
        .padding(.leading, 20)
        .padding(.top, 4)
    }
    
    // MARK: - Helper Functions
    
    private func priorityIcon(for level: String) -> String {
        switch level.lowercased() {
        case "high": return "exclamationmark.3"
        case "medium": return "exclamationmark.2"
        case "low": return "exclamationmark"
        default: return "exclamationmark"
        }
    }
    
    private func priorityColor(for level: String) -> Color {
        switch level.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .yellow
        default: return .gray
        }
    }
}

// MARK: - Previews

#Preview("Compact Buttons") {
    VStack(spacing: 16) {
        // Compact version
        VStack(alignment: .leading, spacing: 4) {
            Text("Compact (next to timestamp)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                AIPromptButtonCompact(
                    icon: "calendar.badge.plus",
                    text: "Add to calendar",
                    tintColor: .blue
                ) {}
                Spacer()
                Text("2:47 PM")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        
        Divider()
        
        // Regular version
        VStack(alignment: .leading, spacing: 8) {
            Text("Regular (below message)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            AIPromptButton(
                icon: "calendar.badge.plus",
                text: "Add to calendar?",
                tintColor: .blue
            ) {}
            
            AIPromptButton(
                icon: "bell.badge.fill",
                text: "Set reminder?",
                tintColor: .orange
            ) {}
            
            AIPromptButton(
                icon: "checkmark.circle.fill",
                text: "Save decision?",
                tintColor: .green
            ) {}
        }
    }
    .padding()
}

