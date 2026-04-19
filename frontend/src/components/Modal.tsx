import { useEffect, type ReactNode } from 'react';

interface ModalProps {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode;
  size?: 'sm' | 'md' | 'lg';
  /** If provided and returns true, ESC / backdrop / close button are blocked. */
  onCloseGuard?: () => boolean;
}

const sizeClass = {
  sm: 'max-w-sm',
  md: 'max-w-lg',
  lg: 'max-w-2xl',
};

export function Modal({ open, onClose, title, children, footer, size = 'md', onCloseGuard }: ModalProps) {
  useEffect(() => {
    if (!open) return;
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (onCloseGuard?.()) return;
        onClose();
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [open, onClose, onCloseGuard]);

  if (!open) return null;

  const requestClose = () => {
    if (onCloseGuard?.()) return;
    onClose();
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4"
      onClick={requestClose}
    >
      <div
        className={`w-full ${sizeClass[size]} rounded-xl bg-[var(--color-bg-light)] border border-[var(--color-current-line)] shadow-2xl flex flex-col max-h-[90vh]`}
        onClick={e => e.stopPropagation()}
      >
        <div className="flex items-center justify-between px-5 py-4 border-b border-[var(--color-current-line)]">
          <h2 className="text-lg font-semibold text-[var(--color-fg)]">{title}</h2>
          <button
            type="button"
            onClick={requestClose}
            aria-label="Close"
            className="w-8 h-8 flex items-center justify-center rounded-lg text-[var(--color-comment)] hover:text-[var(--color-fg)] hover:bg-[var(--color-bg-lighter)] transition-colors cursor-pointer"
          >
            ✕
          </button>
        </div>
        <div className="flex-1 overflow-y-auto p-5">{children}</div>
        {footer && (
          <div className="px-5 py-4 border-t border-[var(--color-current-line)] flex items-center justify-end gap-3">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}
