import { useEffect, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import type { AdminStatus } from "../types";

export function useAdminCheck() {
  const [status, setStatus] = useState<AdminStatus>({
    is_windows: false,
    is_elevated: false,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    invoke<AdminStatus>("check_admin")
      .then(setStatus)
      .finally(() => setLoading(false));
  }, []);

  return { status, loading };
}
