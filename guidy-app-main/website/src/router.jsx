import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";

// The site has four pages and no nested routes, so this is all the routing
// it needs: the address bar, Link, and the current location. It replaces
// react-router-dom, which was a fifth of the JavaScript the site shipped.

const here = () => ({ pathname: window.location.pathname, hash: window.location.hash });
const Ctx = createContext(null);

export function Router({ children }) {
  const [location, setLocation] = useState(here);
  useEffect(() => {
    const sync = () => setLocation(here());
    window.addEventListener("popstate", sync);
    return () => window.removeEventListener("popstate", sync);
  }, []);
  const navigate = useCallback((to) => {
    const next = new URL(to, window.location.href);
    if (next.pathname + next.search + next.hash !== window.location.pathname + window.location.search + window.location.hash) {
      window.history.pushState(null, "", next.pathname + next.search + next.hash);
    }
    setLocation(here());
  }, []);
  const value = useMemo(() => ({ location, navigate }), [location, navigate]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

// oxlint-disable-next-line react/only-export-components
export const useLocation = () => useContext(Ctx).location;

export function Link({ to, onClick, ...rest }) {
  const { navigate } = useContext(Ctx);
  return (
    <a
      href={to}
      {...rest}
      onClick={(e) => {
        onClick?.(e);
        // Let the browser handle new-tab clicks and the like.
        if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || rest.target) return;
        e.preventDefault();
        navigate(to);
      }}
    />
  );
}
