import { describe, expect, it } from 'vitest'

import { renderScaffold } from './scaffold'

describe('tracking web scaffold', () => {
  it('renders the initial broker tracking page', () => {
    const html = renderScaffold()

    expect(html).toContain('Northstar Freight LLC')
    expect(html).toContain('Load NSF-2048')
    expect(html).toContain('App-estimated ETA for Delivery.')
  })
})
