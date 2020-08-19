//
//  PendingCommand.swift
//  DashKit
//
//  Created by Pete Schwamb on 8/19/20.
//  Copyright © 2020 Tidepool. All rights reserved.
//

import Foundation
import PodSDK
import LoopKit

extension ProgramType: Equatable {
    public static func == (lhs: ProgramType, rhs: ProgramType) -> Bool {
        switch (lhs, rhs) {
        case (.basalProgram(let lhsBasal, let lhsSecondsSinceMidnight), .basalProgram(let rhsBasal, let rhsSecondsSinceMidnight)):
            return lhsBasal == rhsBasal && lhsSecondsSinceMidnight == rhsSecondsSinceMidnight
        case (.bolus(let lhsBolus), .bolus(let rhsBolus)):
            return lhsBolus == rhsBolus
        case (.tempBasal(let lhsTempBasal), .tempBasal(let rhsTempBasal)):
            return lhsTempBasal == rhsTempBasal
        default:
            return false
        }
    }
}

public enum PendingCommand: RawRepresentable, Equatable {
    public typealias RawValue = [String: Any]

    case program(ProgramType, Date)
    case stopProgram(StopProgramType, Date)
    
    private enum PendingCommandType: Int {
        case program, stopProgram
    }

    public init?(rawValue: RawValue) {
        guard let rawPendingCommandType = rawValue["type"] as? PendingCommandType.RawValue else {
            return nil
        }
        
        guard let commandDate = rawValue["date"] as? Date else {
            return nil
        }

        switch PendingCommandType(rawValue: rawPendingCommandType) {
        case .program?:
            guard let rawUnacknowledgedProgram = rawValue["unacknowledgedProgram"] as? JSONEncoder.Output else {
                return nil
            }
            let decoder = JSONDecoder()
            if let program = try? decoder.decode(ProgramType.self, from: rawUnacknowledgedProgram) {
                self = .program(program, commandDate)
            } else {
                return nil
            }
        case .stopProgram?:
            guard let rawUnacknowledgedStopProgram = rawValue["unacknowledgedStopProgram"] as? JSONEncoder.Output else {
                return nil
            }
            let decoder = JSONDecoder()
            if let stopProgram = try? decoder.decode(StopProgramType.self, from: rawUnacknowledgedStopProgram) {
                self = .stopProgram(stopProgram, commandDate)
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [:]
        
        switch self {
        case .program(let program, let date):
            rawValue["type"] = PendingCommandType.program.rawValue
            rawValue["date"] = date
            let encoder = JSONEncoder()
            if let rawUnacknowledgedProgram = try? encoder.encode(program) {
                rawValue["unacknowledgedProgram"] = rawUnacknowledgedProgram
            }
        case .stopProgram(let stopProgram, let date):
            rawValue["type"] = PendingCommandType.stopProgram.rawValue
            rawValue["date"] = date
            let encoder = JSONEncoder()
            if let rawUnacknowledgedStopProgram = try? encoder.encode(stopProgram) {
                rawValue["unacknowledgedStopProgram"] = rawUnacknowledgedStopProgram
            }
        }
        return rawValue
    }
    
    public static func == (lhs: PendingCommand, rhs: PendingCommand) -> Bool {
        switch(lhs, rhs) {
        case (.program(let lhsProgram, let lhsDate), .program(let rhsProgram, let rhsDate)):
            return lhsProgram == rhsProgram && lhsDate == rhsDate
        case (.stopProgram(let lhsStopProgram, let lhsDate), .stopProgram(let rhsStopProgram, let rhsDate)):
            return lhsStopProgram == rhsStopProgram && lhsDate == rhsDate
        default:
            return false
        }
    }
}

