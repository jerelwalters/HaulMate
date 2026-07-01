import { describe, expect, it } from 'vitest'

import { renderScaffold } from './scaffold'

describe('tracking web scaffold', () => {
  it('renders the initial broker tracking shell', () => {
    const html = renderScaffold()

    expect(html).toContain('HaulMate broker tracking')
    expect(html).toContain('No broker login.')
    expect(html).toContain(
      'No rates, profit, expenses, precise coordinates, or private documents.',
    )
  })
})
