import type { TrackingResponse } from './types'

export const trackingResponseFixtures = {
  activeLoad: {
    schemaVersion: 1,
    carrier: {
      displayName: 'Northstar Freight LLC',
    },
    load: {
      referenceNumber: 'NSF-2048',
      status: 'en_route_to_delivery',
      currentStopId: null,
      nextStopId: 'stop-delivery',
    },
    stops: [
      {
        id: 'stop-pickup',
        kind: 'pickup',
        displayName: 'Pickup',
        city: 'Detroit',
        region: 'MI',
        appointmentWindow: {
          startsAt: '2026-07-01T13:00:00Z',
          endsAt: '2026-07-01T15:00:00Z',
          timezone: 'America/Detroit',
          displayText: 'Jul 1, 9:00-11:00 AM EDT',
        },
        status: 'completed',
        arrivedAt: '2026-07-01T13:08:00Z',
        departedAt: '2026-07-01T14:12:00Z',
      },
      {
        id: 'stop-delivery',
        kind: 'delivery',
        displayName: 'Delivery',
        city: 'Columbus',
        region: 'OH',
        appointmentWindow: {
          startsAt: '2026-07-01T20:00:00Z',
          endsAt: '2026-07-01T22:00:00Z',
          timezone: 'America/New_York',
          displayText: 'Jul 1, 4:00-6:00 PM EDT',
        },
        status: 'pending',
        arrivedAt: null,
        departedAt: null,
      },
    ],
    eta: {
      status: 'available',
      stopId: 'stop-delivery',
      estimatedArrivalAt: '2026-07-01T20:35:00Z',
      source: 'on_device_estimate',
      refreshedAt: '2026-07-01T18:42:00Z',
    },
    latestDelay: null,
    pod: {
      available: false,
      availableAt: null,
    },
    freshness: {
      status: 'current',
      lastUpdatedAt: '2026-07-01T18:45:00Z',
      displayText: 'Updated 3 minutes ago',
    },
    events: [
      {
        id: 'event-arrived-pickup',
        type: 'arrived',
        stopId: 'stop-pickup',
        occurredAt: '2026-07-01T13:08:00Z',
        summary: 'Arrived at pickup.',
      },
      {
        id: 'event-departed-pickup',
        type: 'departed',
        stopId: 'stop-pickup',
        occurredAt: '2026-07-01T14:12:00Z',
        summary: 'Departed pickup.',
      },
      {
        id: 'event-eta-delivery',
        type: 'eta_published',
        stopId: 'stop-delivery',
        occurredAt: '2026-07-01T18:42:00Z',
        summary: 'ETA published for delivery.',
      },
    ],
  },
  delayedLoad: {
    schemaVersion: 1,
    carrier: {
      displayName: 'Northstar Freight LLC',
    },
    load: {
      referenceNumber: 'NSF-2051',
      status: 'delayed',
      currentStopId: 'stop-pickup',
      nextStopId: 'stop-pickup',
    },
    stops: [
      {
        id: 'stop-pickup',
        kind: 'pickup',
        displayName: 'Pickup',
        city: 'Toledo',
        region: 'OH',
        appointmentWindow: {
          startsAt: '2026-07-02T12:00:00Z',
          endsAt: '2026-07-02T14:00:00Z',
          timezone: 'America/New_York',
          displayText: 'Jul 2, 8:00-10:00 AM EDT',
        },
        status: 'arrived',
        arrivedAt: '2026-07-02T12:06:00Z',
        departedAt: null,
      },
    ],
    eta: {
      status: 'available',
      stopId: 'stop-pickup',
      estimatedArrivalAt: '2026-07-02T12:05:00Z',
      source: 'manual',
      refreshedAt: '2026-07-02T12:00:00Z',
    },
    latestDelay: {
      reason: 'Waiting for dock assignment.',
      reportedAt: '2026-07-02T12:35:00Z',
    },
    pod: {
      available: false,
      availableAt: null,
    },
    freshness: {
      status: 'stale',
      lastUpdatedAt: '2026-07-02T12:36:00Z',
      displayText: 'Last updated 42 minutes ago',
    },
    events: [
      {
        id: 'event-arrived-pickup',
        type: 'arrived',
        stopId: 'stop-pickup',
        occurredAt: '2026-07-02T12:06:00Z',
        summary: 'Arrived at pickup.',
      },
      {
        id: 'event-delay-pickup',
        type: 'delay_reported',
        stopId: 'stop-pickup',
        occurredAt: '2026-07-02T12:35:00Z',
        summary: 'Delay reported.',
      },
    ],
  },
  deliveredLoad: {
    schemaVersion: 1,
    carrier: {
      displayName: 'Northstar Freight LLC',
    },
    load: {
      referenceNumber: 'NSF-2033',
      status: 'delivered',
      currentStopId: null,
      nextStopId: null,
    },
    stops: [
      {
        id: 'stop-delivery',
        kind: 'delivery',
        displayName: 'Delivery',
        city: 'Grand Rapids',
        region: 'MI',
        appointmentWindow: {
          startsAt: '2026-06-30T18:00:00Z',
          endsAt: '2026-06-30T20:00:00Z',
          timezone: 'America/Detroit',
          displayText: 'Jun 30, 2:00-4:00 PM EDT',
        },
        status: 'completed',
        arrivedAt: '2026-06-30T18:11:00Z',
        departedAt: '2026-06-30T19:03:00Z',
      },
    ],
    eta: {
      status: 'unavailable',
      stopId: null,
      estimatedArrivalAt: null,
      source: null,
      refreshedAt: null,
    },
    latestDelay: null,
    pod: {
      available: true,
      availableAt: '2026-06-30T19:22:00Z',
    },
    freshness: {
      status: 'current',
      lastUpdatedAt: '2026-06-30T19:24:00Z',
      displayText: 'Updated after delivery',
    },
    events: [
      {
        id: 'event-arrived-delivery',
        type: 'arrived',
        stopId: 'stop-delivery',
        occurredAt: '2026-06-30T18:11:00Z',
        summary: 'Arrived at delivery.',
      },
      {
        id: 'event-delivered',
        type: 'delivered',
        stopId: 'stop-delivery',
        occurredAt: '2026-06-30T19:03:00Z',
        summary: 'Delivered.',
      },
    ],
  },
} satisfies Record<string, TrackingResponse>
