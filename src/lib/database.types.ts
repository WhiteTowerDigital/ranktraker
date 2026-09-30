// Tipovi baze u formatu `supabase gen types typescript`.
// Posle izmene šeme regenerisati: npm run db:types (zahteva `supabase start`).

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "13.0.5";
  };
  public: {
    Tables: {
      check_runs: {
        Row: {
          id: string;
          created_at: string;
          workspace_id: string;
          started_at: string;
          finished_at: string | null;
          status: string;
          provider: string;
          tasks_total: number;
          tasks_failed: number;
          cost_usd: number;
        };
        Insert: {
          id?: string;
          created_at?: string;
          workspace_id: string;
          started_at?: string;
          finished_at?: string | null;
          status?: string;
          provider: string;
          tasks_total?: number;
          tasks_failed?: number;
          cost_usd?: number;
        };
        Update: {
          id?: string;
          created_at?: string;
          workspace_id?: string;
          started_at?: string;
          finished_at?: string | null;
          status?: string;
          provider?: string;
          tasks_total?: number;
          tasks_failed?: number;
          cost_usd?: number;
        };
        Relationships: [
          {
            foreignKeyName: "check_runs_workspace_id_fkey";
            columns: ["workspace_id"];
            isOneToOne: false;
            referencedRelation: "workspaces";
            referencedColumns: ["id"];
          },
        ];
      };
      keyword_groups: {
        Row: {
          id: string;
          created_at: string;
          workspace_id: string;
          project_id: string;
          name: string;
          seranking_group_id: number | null;
        };
        Insert: {
          id?: string;
          created_at?: string;
          workspace_id: string;
          project_id: string;
          name: string;
          seranking_group_id?: number | null;
        };
        Update: {
          id?: string;
          created_at?: string;
          workspace_id?: string;
          project_id?: string;
          name?: string;
          seranking_group_id?: number | null;
        };
        Relationships: [
          {
            foreignKeyName: "keyword_groups_project_id_workspace_id_fkey";
            columns: ["project_id", "workspace_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id", "workspace_id"];
          },
          {
            foreignKeyName: "keyword_groups_workspace_id_fkey";
            columns: ["workspace_id"];
            isOneToOne: false;
            referencedRelation: "workspaces";
            referencedColumns: ["id"];
          },
        ];
      };
      keywords: {
        Row: {
          id: string;
          created_at: string;
          workspace_id: string;
          project_id: string;
          group_id: string | null;
          keyword: string;
          target_url: string | null;
          depth_override: number | null;
          is_active: boolean;
          next_check_on: string;
          seranking_keyword_id: number | null;
        };
        Insert: {
          id?: string;
          created_at?: string;
          workspace_id: string;
          project_id: string;
          group_id?: string | null;
          keyword: string;
          target_url?: string | null;
          depth_override?: number | null;
          is_active?: boolean;
          next_check_on?: string;
          seranking_keyword_id?: number | null;
        };
        Update: {
          id?: string;
          created_at?: string;
          workspace_id?: string;
          project_id?: string;
          group_id?: string | null;
          keyword?: string;
          target_url?: string | null;
          depth_override?: number | null;
          is_active?: boolean;
          next_check_on?: string;
          seranking_keyword_id?: number | null;
        };
        Relationships: [
          {
            foreignKeyName: "keywords_group_id_project_id_fkey";
            columns: ["group_id", "project_id"];
            isOneToOne: false;
            referencedRelation: "keyword_groups";
            referencedColumns: ["id", "project_id"];
          },
          {
            foreignKeyName: "keywords_project_id_workspace_id_fkey";
            columns: ["project_id", "workspace_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id", "workspace_id"];
          },
          {
            foreignKeyName: "keywords_workspace_id_fkey";
            columns: ["workspace_id"];
            isOneToOne: false;
            referencedRelation: "workspaces";
            referencedColumns: ["id"];
          },
        ];
      };
      positions: {
        Row: {
          id: string;
          created_at: string;
          workspace_id: string;
          keyword_id: string;
          checked_on: string;
          position: number | null;
          ranking_url: string | null;
          matches_target: boolean | null;
          depth_checked: number;
          source: string;
          cost_usd: number;
        };
        Insert: {
          id?: string;
          created_at?: string;
          workspace_id: string;
          keyword_id: string;
          checked_on: string;
          position?: number | null;
          ranking_url?: string | null;
          matches_target?: boolean | null;
          depth_checked: number;
          source: string;
          cost_usd?: number;
        };
        Update: {
          id?: string;
          created_at?: string;
          workspace_id?: string;
          keyword_id?: string;
          checked_on?: string;
          position?: number | null;
          ranking_url?: string | null;
          matches_target?: boolean | null;
          depth_checked?: number;
          source?: string;
          cost_usd?: number;
        };
        Relationships: [
          {
            foreignKeyName: "positions_keyword_id_workspace_id_fkey";
            columns: ["keyword_id", "workspace_id"];
            isOneToOne: false;
            referencedRelation: "keywords";
            referencedColumns: ["id", "workspace_id"];
          },
          {
            foreignKeyName: "positions_workspace_id_fkey";
            columns: ["workspace_id"];
            isOneToOne: false;
            referencedRelation: "workspaces";
            referencedColumns: ["id"];
          },
        ];
      };
      projects: {
        Row: {
          id: string;
          created_at: string;
          workspace_id: string;
          name: string;
          domain: string;
          match_mode: string;
          location_code: number;
          language_code: string;
          device: string;
          check_interval_days: number;
          is_active: boolean;
          seranking_site_id: number | null;
        };
        Insert: {
          id?: string;
          created_at?: string;
          workspace_id: string;
          name: string;
          domain: string;
          match_mode?: string;
          location_code: number;
          language_code: string;
          device?: string;
          check_interval_days?: number;
          is_active?: boolean;
          seranking_site_id?: number | null;
        };
        Update: {
          id?: string;
          created_at?: string;
          workspace_id?: string;
          name?: string;
          domain?: string;
          match_mode?: string;
          location_code?: number;
          language_code?: string;
          device?: string;
          check_interval_days?: number;
          is_active?: boolean;
          seranking_site_id?: number | null;
        };
        Relationships: [
          {
            foreignKeyName: "projects_workspace_id_fkey";
            columns: ["workspace_id"];
            isOneToOne: false;
            referencedRelation: "workspaces";
            referencedColumns: ["id"];
          },
        ];
      };
      serp_snapshots: {
        Row: {
          id: string;
          created_at: string;
          workspace_id: string;
          keyword_id: string;
          checked_on: string;
          results: Json;
        };
        Insert: {
          id?: string;
          created_at?: string;
          workspace_id: string;
          keyword_id: string;
          checked_on: string;
          results?: Json;
        };
        Update: {
          id?: string;
          created_at?: string;
          workspace_id?: string;
          keyword_id?: string;
          checked_on?: string;
          results?: Json;
        };
        Relationships: [
          {
            foreignKeyName: "serp_snapshots_keyword_id_workspace_id_fkey";
            columns: ["keyword_id", "workspace_id"];
            isOneToOne: false;
            referencedRelation: "keywords";
            referencedColumns: ["id", "workspace_id"];
          },
          {
            foreignKeyName: "serp_snapshots_workspace_id_fkey";
            columns: ["workspace_id"];
            isOneToOne: false;
            referencedRelation: "workspaces";
            referencedColumns: ["id"];
          },
        ];
      };
      serp_tasks: {
        Row: {
          id: string;
          created_at: string;
          workspace_id: string;
          run_id: string;
          keyword_id: string;
          provider_task_id: string | null;
          depth: number;
          status: string;
          attempts: number;
          cost_usd: number;
          error: string | null;
        };
        Insert: {
          id?: string;
          created_at?: string;
          workspace_id: string;
          run_id: string;
          keyword_id: string;
          provider_task_id?: string | null;
          depth: number;
          status?: string;
          attempts?: number;
          cost_usd?: number;
          error?: string | null;
        };
        Update: {
          id?: string;
          created_at?: string;
          workspace_id?: string;
          run_id?: string;
          keyword_id?: string;
          provider_task_id?: string | null;
          depth?: number;
          status?: string;
          attempts?: number;
          cost_usd?: number;
          error?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "serp_tasks_keyword_id_workspace_id_fkey";
            columns: ["keyword_id", "workspace_id"];
            isOneToOne: false;
            referencedRelation: "keywords";
            referencedColumns: ["id", "workspace_id"];
          },
          {
            foreignKeyName: "serp_tasks_run_id_workspace_id_fkey";
            columns: ["run_id", "workspace_id"];
            isOneToOne: false;
            referencedRelation: "check_runs";
            referencedColumns: ["id", "workspace_id"];
          },
          {
            foreignKeyName: "serp_tasks_workspace_id_fkey";
            columns: ["workspace_id"];
            isOneToOne: false;
            referencedRelation: "workspaces";
            referencedColumns: ["id"];
          },
        ];
      };
      workspace_members: {
        Row: {
          id: string;
          created_at: string;
          workspace_id: string;
          user_id: string;
          role: string;
        };
        Insert: {
          id?: string;
          created_at?: string;
          workspace_id: string;
          user_id: string;
          role?: string;
        };
        Update: {
          id?: string;
          created_at?: string;
          workspace_id?: string;
          user_id?: string;
          role?: string;
        };
        Relationships: [
          {
            foreignKeyName: "workspace_members_workspace_id_fkey";
            columns: ["workspace_id"];
            isOneToOne: false;
            referencedRelation: "workspaces";
            referencedColumns: ["id"];
          },
        ];
      };
      workspaces: {
        Row: {
          id: string;
          created_at: string;
          name: string;
        };
        Insert: {
          id?: string;
          created_at?: string;
          name: string;
        };
        Update: {
          id?: string;
          created_at?: string;
          name?: string;
        };
        Relationships: [];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      [_ in never]: never;
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type PublicSchema = Database["public"];

export type Tables<T extends keyof PublicSchema["Tables"]> = PublicSchema["Tables"][T]["Row"];
export type TablesInsert<T extends keyof PublicSchema["Tables"]> =
  PublicSchema["Tables"][T]["Insert"];
export type TablesUpdate<T extends keyof PublicSchema["Tables"]> =
  PublicSchema["Tables"][T]["Update"];
