//
//  ReadReceiptBadge.swift
//  MessageAI
//
//  Created by Dev Agent on 2025-10-22.
//  Story 4.1: Improved read receipt UI with count indicator
//

import SwiftUI

/// Blue circle badge showing read receipt count with white checkmark
struct ReadReceiptBadge: View {
    
    let readCount: Int
    
    var body: some View {
        HStack(spacing: 2) {
            // Blue circle with white checkmark
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 14, height: 14)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Count number to the right (only for group chats)
            if readCount > 1 {
                Text("\(readCount)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
        .accessibilityLabel(readCount == 1 ? "Read" : "Read by \(readCount) people")
    }
}

// MARK: - Preview

#Preview("Single Reader") {
    ReadReceiptBadge(readCount: 1)
        .padding()
}

#Preview("Multiple Readers") {
    ReadReceiptBadge(readCount: 5)
        .padding()
}

#Preview("Large Number") {
    ReadReceiptBadge(readCount: 12)
        .padding()
}

#Preview("In Context") {
    VStack(spacing: 20) {
        HStack {
            Text("10:30 AM")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            ReadReceiptBadge(readCount: 1)
        }
        
        HStack {
            Text("10:31 AM")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            ReadReceiptBadge(readCount: 3)
        }
    }
    .padding()
}

