export type TrackingStateVariant = 'loading' | 'missing-token' | 'unavailable'

const stateCopy: Record<
  TrackingStateVariant,
  { heading: string; message: string; title: string }
> = {
  loading: {
    title: 'Loading tracking update',
    heading: 'Loading tracking update',
    message: 'Checking the most recent load update.',
  },
  'missing-token': {
    title: 'Tracking link unavailable',
    heading: 'Tracking link unavailable',
    message: 'Open the secure tracking link sent by the carrier.',
  },
  unavailable: {
    title: 'Tracking temporarily unavailable',
    heading: 'Tracking temporarily unavailable',
    message: 'Try refreshing this page in a moment.',
  },
}

export function renderTrackingState(
  variant: TrackingStateVariant,
  options: { canRetry?: boolean } = {},
) {
  const copy = stateCopy[variant]

  return `
    <main class="tracking-page state-page" aria-labelledby="page-title">
      <section class="state-panel">
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
