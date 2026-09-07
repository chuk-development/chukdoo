import { useCallback, useSyncExternalStore } from 'react';
import { store } from './store';

let version = 0;

// Subscribe wraps listener to bump version
function subscribe(callback: () => void): () => void {
  return store.subscribe(() => {
    version++;
    callback();
  });
}

function getSnapshot(): number {
  return version;
}

export function useStoreState() {
  useSyncExternalStore(subscribe, getSnapshot);
  return store;
}
