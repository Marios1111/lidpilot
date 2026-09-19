import Foundation

public enum SessionDeadlineError: Error, Equatable, Sendable {
    case invalidClock
    case invalidDuration
    case invalidAbsoluteDate
    case invalidStructure
}

public struct SessionDeadline: Codable, Equatable, Sendable {
    public let duration: SessionDuration
    public let startedAt: ClockSample
    public let hardContinuousEnd: Double?
    public let hardAbsoluteEnd: Date?

    public init(duration: SessionDuration, clock: ClockSample) throws {
        guard clock.isValid else {
            throw SessionDeadlineError.invalidClock
        }

        self.duration = duration
        self.startedAt = clock

        switch duration {
        case let .seconds(seconds):
            guard seconds.isFinite, seconds > 0 else {
                throw SessionDeadlineError.invalidDuration
            }
            let end = clock.continuousSeconds + seconds
            guard end.isFinite, end > clock.continuousSeconds else {
                throw SessionDeadlineError.invalidDuration
            }
            self.hardContinuousEnd = end
            self.hardAbsoluteEnd = nil
        case let .until(date):
            guard date.timeIntervalSinceReferenceDate.isFinite,
                  date > clock.wallDate else {
                throw SessionDeadlineError.invalidAbsoluteDate
            }
            self.hardContinuousEnd = nil
            self.hardAbsoluteEnd = date
        case .indefinite:
            self.hardContinuousEnd = nil
            self.hardAbsoluteEnd = nil
        }
    }

    public var bootID: String {
        startedAt.bootID
    }

    public func validate() throws {
        guard startedAt.isValid else {
            throw SessionDeadlineError.invalidClock
        }

        switch duration {
        case let .seconds(seconds):
            guard seconds.isFinite, seconds > 0,
                  let end = hardContinuousEnd,
                  end.isFinite,
                  end > startedAt.continuousSeconds,
                  hardAbsoluteEnd == nil,
                  end == startedAt.continuousSeconds + seconds else {
                throw SessionDeadlineError.invalidStructure
            }
        case let .until(date):
            guard date.timeIntervalSinceReferenceDate.isFinite,
                  let end = hardAbsoluteEnd,
                  end == date,
                  end > startedAt.wallDate,
                  hardContinuousEnd == nil else {
                throw SessionDeadlineError.invalidStructure
            }
        case .indefinite:
            guard hardContinuousEnd == nil, hardAbsoluteEnd == nil else {
                throw SessionDeadlineError.invalidStructure
            }
        }
    }

    public func isExpired(at clock: ClockSample) -> Bool {
        switch duration {
        case .indefinite:
            return false
        case .seconds:
            guard clock.isValid,
                  clock.bootID == startedAt.bootID,
                  let end = hardContinuousEnd else {
                return true
            }
            return clock.continuousSeconds >= end
        case .until:
            guard clock.isValid,
                  clock.bootID == startedAt.bootID,
                  clock.wallDate.timeIntervalSinceReferenceDate.isFinite,
                  let end = hardAbsoluteEnd else {
                return true
            }
            return clock.wallDate >= end
        }
    }

    public func remaining(at clock: ClockSample) -> Double? {
        switch duration {
        case .indefinite:
            return nil
        case let .seconds(seconds):
            guard clock.isValid,
                  clock.bootID == startedAt.bootID,
                  let end = hardContinuousEnd else {
                return 0
            }
            return max(0, min(seconds, end - clock.continuousSeconds))
        case .until:
            guard clock.isValid,
                  clock.bootID == startedAt.bootID,
                  clock.wallDate.timeIntervalSinceReferenceDate.isFinite,
                  let end = hardAbsoluteEnd else {
                return 0
            }
            return max(0, end.timeIntervalSince(clock.wallDate))
        }
    }

    private enum CodingKeys: String, CodingKey {
        case duration
        case startedAt
        case hardContinuousEnd
        case hardAbsoluteEnd
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.duration = try container.decode(SessionDuration.self, forKey: .duration)
        self.startedAt = try container.decode(ClockSample.self, forKey: .startedAt)
        self.hardContinuousEnd = try container.decodeIfPresent(Double.self, forKey: .hardContinuousEnd)
        self.hardAbsoluteEnd = try container.decodeIfPresent(Date.self, forKey: .hardAbsoluteEnd)
        try validate()
    }

    public func encode(to encoder: Encoder) throws {
        try validate()
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(duration, forKey: .duration)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(hardContinuousEnd, forKey: .hardContinuousEnd)
        try container.encodeIfPresent(hardAbsoluteEnd, forKey: .hardAbsoluteEnd)
    }
}
