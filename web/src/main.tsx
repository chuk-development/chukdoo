import React from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './components/App';
import './compiled.css';

const root = createRoot(document.getElementById('root')!);
root.render(<App />);
