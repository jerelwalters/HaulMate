import { describe, expect, it } from 'vitest'

import { readShareTokenFromUrl } from './shareToken'

describe('readShareTokenFromUrl', () => {
  it('reads supported query-string token keys', () => {
    expect(
      readShareTokenFromUrl(new URL('https://tracking.example/load?token=abc')),
    ).toEqual({ kind: 'found', token: 'abc' })
    expect(
      readShareTokenFromUrl(new URL('https://tracking.example/load?share=def')),
    ).toEqual({ kind: 'found', token: 'def' })
    expect(
      readShareTokenFromUrl(
        new URL('https://tracking.example/load?shareToken=ghi'),
      ),
    ).toEqual({ kind: 'found', token: 'ghi' })
  })

  it('reads /track/:token links', () => {
    expect(
      readShareTokenFromUrl(new URL('https://tracking.example/track/path-token')),
    ).toEqual({ kind: 'found', token: 'path-token' })
  })

  it('does not return empty tokens', () => {
    expect(
      readShareTokenFromUrl(new URL('https://tracking.example/load?token=   ')),
    ).toEqual({ kind: 'missing' })
  })
})
