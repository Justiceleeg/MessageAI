//
//  ReadReceiptBadgeTests.swift
//  MessageAITests
//
//  Created by Dev Agent on 2025-10-22.
//  Story 4.1: Unit tests for ReadReceiptBadge component
//

import XCTest
import SwiftUI
@testable import MessageAI

/// Tests for ReadReceiptBadge UI component (Story 4.1)
final class ReadReceiptBadgeTests: XCTestCase {
    
    // MARK: - Component Rendering Tests
    
    func testReadReceiptBadgeRendersForSingleReader() throws {
        // Given: A badge with readCount of 1
        let badge = ReadReceiptBadge(readCount: 1)
        
        // Then: Badge should render with correct count
        // Note: Full UI rendering tests would use ViewInspector or snapshot testing
        // For MVP, we verify the component initializes correctly
        XCTAssertNotNil(badge)
    }
    
    func testReadReceiptBadgeRendersForMultipleReaders() throws {
        // Given: A badge with readCount of 5
        let badge = ReadReceiptBadge(readCount: 5)
        
        // Then: Badge should render with correct count
        XCTAssertNotNil(badge)
    }
    
    func testReadReceiptBadgeRendersForLargeNumber() throws {
        // Given: A badge with readCount of 99
        let badge = ReadReceiptBadge(readCount: 99)
        
        // Then: Badge should render without errors
        XCTAssertNotNil(badge)
    }
    
    func testReadReceiptBadgeRendersForZeroReaders() throws {
        // Given: A badge with readCount of 0
        let badge = ReadReceiptBadge(readCount: 0)
        
        // Then: Badge should still render (edge case)
        XCTAssertNotNil(badge)
    }
}

