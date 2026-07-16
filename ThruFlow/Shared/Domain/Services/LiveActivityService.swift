//
//  LiveActivityService.swift
//  ThruFlow
//
//  Created by Codex on 2026/07/08.
//

import Foundation

struct FlowLiveActivityContent: Equatable {
    var directionEmoji: String
    var directionName: String
    var todoTitle: String?
    var modeName: String
    var phase: FlowPhase
    var plannedEndAt: Date
}

protocol LiveActivityService {
    func start(content: FlowLiveActivityContent)
    func update(content: FlowLiveActivityContent)
    func end()
}

struct NoopLiveActivityService: LiveActivityService {
    func start(content: FlowLiveActivityContent) {}
    func update(content: FlowLiveActivityContent) {}
    func end() {}
}
