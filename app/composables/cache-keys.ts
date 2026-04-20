type RootKey<R extends string> = readonly [R]
type ListKey<R extends string> = readonly [...RootKey<R>, 'list']
type DetailKey<R extends string> = readonly [...RootKey<R>, 'detail']

const createRootKey = <R extends string>(rootKey: R): RootKey<R> => [rootKey]
const createListKey = <R extends string>(rootKey: R): ListKey<R> => [
  ...createRootKey(rootKey),
  'list',
]
const createDetailKey = <R extends string>(rootKey: R): DetailKey<R> => [
  ...createRootKey(rootKey),
  'detail',
]

type KeyPart = string | number

type ChildBase<R extends string> = readonly [R, ...KeyPart[]]

type CreateKeyFn<R extends string> = <T extends readonly KeyPart[]>(
  ...args: T
) => readonly [R, ...T]

type AppendKeyFn<R extends string> = <
  B extends ChildBase<R>,
  T extends readonly KeyPart[],
>(
  base: B,
  ...parts: T
) => readonly [...B, ...T]

export interface CacheKeys<R extends string> {
  root: RootKey<R>
  list: ListKey<R>
  detail: DetailKey<R>
  detailById: (id: KeyPart) => readonly [...DetailKey<R>, KeyPart]
}

export const createCacheKeys = <
  R extends string,
  Ext extends Record<
    string,
    | readonly [R, ...KeyPart[]]
    // biome-ignore lint/suspicious/noExplicitAny: We're extended our keys here.
    | ((...args: any[]) => readonly [R, ...KeyPart[]])
  > = Record<string, never>,
>(
  rootKey: R,
  extend?: (createKey: CreateKeyFn<R>, appendKey: AppendKeyFn<R>) => Ext,
) => {
  const createKey: CreateKeyFn<R> = (...args) => {
    return [rootKey, ...args] as const
  }

  const appendKey: AppendKeyFn<R> = (base, ...parts) => {
    return [...base, ...parts] as const
  }

  const detailBase = createDetailKey(rootKey)

  const base: CacheKeys<R> = {
    root: createRootKey(rootKey),
    list: createListKey(rootKey),
    detail: detailBase,
    detailById: (id) => appendKey(detailBase, id),
  }

  const extended = extend ? extend(createKey, appendKey) : ({} as Ext)

  return {
    ...base,
    ...extended,
  } as CacheKeys<R> & Ext
}
