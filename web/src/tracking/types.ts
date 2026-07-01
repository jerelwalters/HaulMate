export type ISODateTime = string
export type PublicId = string

export type TrackingLoadStatus =
  | 'not_started'
  | 'en_route_to_pickup'
  | 'at_pickup'
  | 'loaded'
  | 'en_route_to_delivery'
  | 'at_delivery'
  | 'delayed'
  | 'delivered'
  | 'cancelled'

export type TrackingStopKind = 'pickup' | 'delivery'

export type TrackingStopStatus =
  | 'pending'
  | 'arrived'
  | 'departed'
  | 'completed'

export type TrackingEtaSource = 'manual' | 'on_device_estimate'
export type TrackingEtaStatus = 'available' | 'unavailable'
export type TrackingFreshnessStatus = 'current' | 'stale' | 'offline_no_update'

export type TrackingEventType =
  | 'eta_published'
  | 'arrived'
  | 'departed'
  | 'loaded'
  | 'delivered'
  | 'delay_reported'

export interface TrackingResponse {
  schemaVersion: 1
  carrier: TrackingCarrier
  load: TrackingLoad
  stops: TrackingStop[]
  eta: TrackingEta
  latestDelay: TrackingDelay | null
  pod: TrackingPodAvailability
  freshness: TrackingFreshness
  events: TrackingEvent[]
}

export interface TrackingCarrier {
  displayName: string
}

export interface TrackingLoad {
  referenceNumber: string
  status: TrackingLoadStatus
  currentStopId: PublicId | null
  nextStopId: PublicId | null
}

export interface TrackingStop {
  id: PublicId
  kind: TrackingStopKind
  displayName: string
  city: string
  region: string
  appointmentWindow: TrackingAppointmentWindow | null
  status: TrackingStopStatus
  arrivedAt: ISODateTime | null
  departedAt: ISODateTime | null
}

export interface TrackingAppointmentWindow {
  startsAt: ISODateTime
  endsAt: ISODateTime
  timezone: string
  displayText: string
}

export interface TrackingEta {
  status: TrackingEtaStatus
  stopId: PublicId | null
  estimatedArrivalAt: ISODateTime | null
  source: TrackingEtaSource | null
  refreshedAt: ISODateTime | null
}

export interface TrackingDelay {
  reason: string
  reportedAt: ISODateTime
}

export interface TrackingPodAvailability {
  available: boolean
  availableAt: ISODateTime | null
}

export interface TrackingFreshness {
  status: TrackingFreshnessStatus
  lastUpdatedAt: ISODateTime
  displayText: string
}

export interface TrackingEvent {
  id: PublicId
  type: TrackingEventType
  stopId: PublicId | null
  occurredAt: ISODateTime
  summary: string
}
