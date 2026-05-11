import { useEffect, useMemo, useState } from "react";
import { JSONCrack } from "jsoncrack-react";
import type { LayoutDirection, NodeData } from "jsoncrack-react";

type SessionPayload = {
  title: string;
  jsonText: string;
  mode: "schema" | "data" | "auto";
};

function chooseLayout(mode: SessionPayload["mode"]): LayoutDirection {
  if (mode === "schema") {
    return "DOWN";
  }
  return "RIGHT";
}

export function App() {
  const [session, setSession] = useState<SessionPayload | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [jumpState, setJumpState] = useState<string>("");

  useEffect(() => {
    let active = true;

    fetch("/api/session")
      .then(async response => {
        if (!response.ok) {
          throw new Error(`Session load failed (${response.status})`);
        }
        return (await response.json()) as SessionPayload;
      })
      .then(data => {
        if (!active) {
          return;
        }
        setSession(data);
      })
      .catch(err => {
        if (!active) {
          return;
        }
        setError(err instanceof Error ? err.message : "Unable to load session");
      });

    return () => {
      active = false;
    };
  }, []);

  const parsedJson = useMemo(() => {
    if (!session) {
      return null;
    }
    try {
      return JSON.parse(session.jsonText);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Invalid JSON payload");
      return null;
    }
  }, [session]);

  const onNodeClick = async (node: NodeData) => {
    const path = Array.isArray(node.path) ? node.path : null;
    if (!path) {
      setJumpState("Node has no path metadata");
      return;
    }

    try {
      const response = await fetch("/api/jump", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ path }),
      });
      if (!response.ok) {
        throw new Error(`Jump failed (${response.status})`);
      }
      setJumpState(`Jumped to path: ${JSON.stringify(path)}`);
    } catch (err) {
      setJumpState(err instanceof Error ? err.message : "Jump request failed");
    }
  };

  if (error) {
    return <div className="error">{error}</div>;
  }

  if (!session || !parsedJson) {
    return <div className="loading">Loading graph555</div>;
  }

  return (
    <div className="page">
      <header className="bar">
        <div>
          <h1>{session.title || "JSON Graph"}</h1>
          <p className="meta">Mode: {session.mode}</p>
        </div>
        <div className="meta">Click any node to jump in Neovim</div>