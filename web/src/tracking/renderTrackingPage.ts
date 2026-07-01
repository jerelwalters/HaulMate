import type {
  TrackingEta,
  TrackingEvent,
  TrackingLoadStatus,
  TrackingResponse,
  TrackingStop,
} from './types'

const loadStatusLabels: Record<TrackingLoadStatus, string> = {
  not_started: 'Not started',
  en_route_to_pickup: 'En route to pickup',
  at_pickup: 'At pickup',
  loaded: 'Loaded',
  en_route_to_delivery: 'En route to delivery',
  at_delivery: 'At delivery',
  delayed: 'Delayed',
  delivered: 'Delivered',
  cancelled: 'Cancelled',
}

const eventLabels: Record<TrackingEvent['type'], string> = {
  eta_published: 'ETA updated',
  arrived: 'Arrival',
  departed: 'Departure',
  loaded: 'Loaded',
  delivered: 'Delivered',
  delay_reported: 'Delay reported',
}

export function renderTrackingPage(response: TrackingResponse) {
  return `
    <main class="tracking-page" aria-labelledby="page-title">
      <header class="tracking-header">
        <div>
          <p class="carrier-name">${escapeHtml(response.carrier.displayName)}</p>
          <h1 id="page-title">Load ${escapeHtml(response.load.referenceNumber)}</h1>
        </div>

        <div class="load-status" aria-label="Load status">
          <span class="status-dot" aria-hidden="true"></span>
          <span>${escapeHtml(loadStatusLabels[response.load.status])}</span>
        </div>
      </header>

      <section class="summary-grid" aria-label="Tracking summary">
        ${renderEta(response.eta, response.stops)}
        ${renderFreshness(response)}
        ${renderPod(response)}
      </section>

      ${renderDelay(response)}

      <section class="content-grid">
        <section class="panel stops-panel" aria-labelledby="stops-heading">
          <div class="panel-heading">
            <h2 id="stops-heading">Stops</h2>
            <span>${response.stops.length} planned</span>
          </div>
          <ol class="stops-list">
            ${response.stops.map((stop) => renderStop(stop, response)).join('')}
          </ol>
        </section>

        <section class="panel events-panel" aria-labelledby="events-heading">
          <div class="panel-heading">
            <h2 id="events-heading">Latest events</h2>
            <span>${response.events.length} visible</span>
          </div>
          <ol class="events-list">
            ${response.events.map(renderEvent).join('')}
          </ol>
        </section>
      </section>
    </main>
  `
}

function renderEta(eta: TrackingEta, stops: TrackingStop[]) {
  const etaStop = stops.find((stop) => stop.id === eta.stopId)
  const etaTitle = etaStop
    ? `${capitalize(etaStop.kind)} ETA`
    : 'ETA'

  if (eta.status === 'unavailable') {
    return `
      <article class="summary-card">
        <span class="summary-label">${etaTitle}</span>
        <strong>Unavailable</strong>
        <p>No active ETA is currently published.</p>
      </article>
    `
  }

  return `
    <article class="summary-card">
      <span class="summary-label">${etaTitle}</span>
      <strong>${formatTime(eta.estimatedArrivalAt)}</strong>
      <p>${eta.source === 'manual' ? 'Manual estimate' : 'On-device estimate'} for ${escapeHtml(etaStop?.displayName ?? 'the next stop')}.</p>
    </article>
  `
}

function renderFreshness(response: TrackingResponse) {
  return `
    <article class="summary-card">
      <span class="summary-label">Freshness</span>
      <strong>${escapeHtml(statusToTitle(response.freshness.status))}</strong>
      <p>${escapeHtml(response.freshness.displayText)}</p>
    </article>
  `
}

function renderPod(response: TrackingResponse) {
  const podText = response.pod.available
    ? `Available ${formatTime(response.pod.availableAt)}`
    : 'Not available yet'

  return `
    <article class="summary-card">
      <span class="summary-label">POD</span>
      <strong>${response.pod.available ? 'Ready' : 'Pending'}</strong>
      <p>${escapeHtml(podText)}</p>
    </article>
  `
}

function renderDelay(response: TrackingResponse) {
  if (!response.latestDelay) {
    return ''
  }

  return `
    <section class="delay-banner" aria-label="Delay update">
      <div>
        <span class="summary-label">Delay</span>
        <p>${escapeHtml(response.latestDelay.reason)}</p>
      </div>
      <time datetime="${escapeHtml(response.latestDelay.reportedAt)}">${formatTime(response.latestDelay.reportedAt)}</time>
    </section>
  `
}

function renderStop(stop: TrackingStop, response: TrackingResponse) {
  const isCurrent = response.load.currentStopId === stop.id
  const isNext = response.load.nextStopId === stop.id
  const badge = isCurrent ? 'Current' : isNext ? 'Next' : statusToTitle(stop.status)

  return `
    <li class="stop-item ${isCurrent || isNext ? 'is-active' : ''}">
      <div class="timeline-marker" aria-hidden="true"></div>
      <div class="stop-content">
        <div class="stop-heading">
          <div>
            <span class="summary-label">${capitalize(stop.kind)}</span>
            <h3>${escapeHtml(stop.displayName)}</h3>
          </div>
          <span class="state-chip">${escapeHtml(badge)}</span>
        </div>
        <p>${escapeHtml(stop.city)}, ${escapeHtml(stop.region)}</p>
        ${renderAppointment(stop)}
        <dl class="stop-times">
          ${renderTimeRow('Arrived', stop.arrivedAt)}
          ${renderTimeRow('Departed', stop.departedAt)}
        </dl>
      </div>
    </li>
  `
}

function renderAppointment(stop: TrackingStop) {
  if (!stop.appointmentWindow) {
    return '<p class="appointment">Appointment window unavailable</p>'
  }

  return `
    <p class="appointment">
      <span>Appointment</span>
      <time datetime="${escapeHtml(stop.appointmentWindow.startsAt)}">${escapeHtml(stop.appointmentWindow.displayText)}</time>
    </p>
  `
}

function renderTimeRow(label: string, value: string | null) {
  return `
    <div>
      <dt>${escapeHtml(label)}</dt>
      <dd>${value ? formatTime(value) : 'Not recorded'}</dd>
    </div>
  `
}

function renderEvent(event: TrackingEvent) {
  return `
    <li>
      <time datetime="${escapeHtml(event.occurredAt)}">${formatTime(event.occurredAt)}</time>
      <div>
        <strong>${escapeHtml(eventLabels[event.type])}</strong>
        <p>${escapeHtml(event.summary)}</p>
      </div>
    </li>
  `
}

function formatTime(value: string | null) {
  if (!value) {
    return 'Not available'
  }

  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    timeZoneName: 'short',
  }).format(new Date(value))
}

function statusToTitle(value: string) {
  return value
    .split('_')
    .map(capitalize)
    .join(' ')
}

function capitalize(value: string) {
  return value.charAt(0).toUpperCase() + value.slice(1)
}

function escapeHtml(value: string) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}
