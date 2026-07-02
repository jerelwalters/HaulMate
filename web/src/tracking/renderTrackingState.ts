export type TrackingStateVariant =
  | 'loading'
  | 'unavailable-link'
  | 'service-unavailable'

const stateCopy: Record<
  TrackingStateVariant,
  { heading: string; message: string; role: 'alert' | 'status'; title: string }
> = {
  loading: {
    title: 'Loading tracking update',
    heading: 'Loading tracking update',
    message: 'Checking the most recent load update.',
    role: 'status',
  },
  'unavailable-link': {
    title: 'Tracking link unavailable',
    heading: 'Tracking link unavailable',
    message: 'This secure tracking link is unavailable. Ask the carrier for a new link.',
    role: 'alert',
  },
  'service-unavailable': {
    title: 'Tracking temporarily unavailable',
    heading: 'Tracking temporarily unavailable',
    message: 'Tracking updates cannot be checked right now. Try again in a moment.',
    role: 'alert',
  },
}

export function renderTrackingState(
  variant: TrackingStateVariant,
  options: { canRetry?: boolean } = {},
) {
  const copy = stateCopy[variant]

  return `
    <main class="tracking-page state-page" aria-labelledby="page-title">
      <section
        class="state-panel"
        data-tracking-state="${variant}"
        role="${copy.role}"
        aria-live="${copy.role === 'status' ? 'polite' : 'assertive'}"
      >
        <p class="carrier-name">HaulMate tracking</p>
        <h1 id="page-title">${copy.heading}</h1>
        <p>${copy.message}</p>
        ${
          options.canRetry
            ? '<button class="retry-button" type="button" data-action="retry-tracking">Retry</button>'
            : ''
        }
      </section>
    </main>
  `
}
