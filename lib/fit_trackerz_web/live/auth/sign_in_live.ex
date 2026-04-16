defmodule FitTrackerzWeb.Auth.SignInLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Sign In", form: to_form(%{}, as: "user"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex relative overflow-hidden">
      <%!-- Left: Branding Panel --%>
      <div class="hidden lg:flex lg:w-1/2 relative overflow-hidden
                  bg-gradient-to-br from-primary/25 via-base-200 to-secondary/15">
        <%!-- Multi-blob glow --%>
        <div class="absolute inset-0">
          <div class="absolute top-16 left-10 w-72 h-72 rounded-full bg-primary/40 blur-3xl animate-float-slow opacity-60"></div>
          <div class="absolute bottom-16 right-10 w-80 h-80 rounded-full bg-secondary/40 blur-3xl animate-float-slow opacity-50" style="animation-delay: 3s;"></div>
          <div class="absolute top-1/2 left-1/3 w-56 h-56 rounded-full bg-accent/30 blur-3xl animate-float opacity-40" style="animation-delay: 1.5s;"></div>
        </div>

        <div class="relative z-10 flex flex-col items-center justify-center w-full p-12 animate-slide-in-left">
          <div class="text-center max-w-lg">
            <div class="flex items-center justify-center gap-3 mb-6">
              <div class="w-16 h-16 rounded-2xl bg-gradient-to-br from-primary to-secondary flex items-center justify-center shadow-[0_8px_24px_-4px_oklch(40%_0.22_280_/_0.5)]">
                <.icon name="hero-bolt-solid" class="size-9 text-primary-content" />
              </div>
            </div>
            <.brand_logo class="h-20 w-auto mx-auto" dumbbell={true} />
            <p class="mt-4 text-lg text-base-content/70 leading-relaxed">
              Your all-in-one fitness platform. Discover gyms, book classes, and transform your fitness journey.
            </p>
            <div class="mt-10 grid grid-cols-3 gap-3 text-center">
              <div class="surface-2 p-4 reveal" style="--reveal-delay: 200ms">
                <div class="text-2xl font-black text-gradient-brand">500+</div>
                <div class="text-xs text-base-content/50 mt-1 font-semibold uppercase tracking-wider">Gyms</div>
              </div>
              <div class="surface-2 p-4 reveal" style="--reveal-delay: 350ms">
                <div class="text-2xl font-black text-gradient-brand">1K+</div>
                <div class="text-xs text-base-content/50 mt-1 font-semibold uppercase tracking-wider">Classes</div>
              </div>
              <div class="surface-2 p-4 reveal" style="--reveal-delay: 500ms">
                <div class="text-2xl font-black text-gradient-brand">50K+</div>
                <div class="text-xs text-base-content/50 mt-1 font-semibold uppercase tracking-wider">Members</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Right: Sign In Form --%>
      <div class="flex-1 flex items-center justify-center p-6 sm:p-12 relative">
        <%!-- Subtle glow behind form --%>
        <div class="pointer-events-none absolute top-1/3 left-1/2 -translate-x-1/2 w-[480px] h-[480px] rounded-full bg-primary/15 blur-3xl"></div>

        <div class="w-full max-w-md animate-fade-up relative z-10 surface-3 accent-top p-8 sm:p-10">
          <%!-- Mobile Logo --%>
          <div class="lg:hidden flex items-center justify-center mb-10">
            <.brand_logo class="h-14 w-auto" dumbbell={true} />
          </div>

          <div class="text-center mb-8">
            <h2 class="text-2xl sm:text-3xl font-brand text-gradient-brand">Welcome back</h2>
            <p class="text-base-content/60 mt-2">Sign in to your account to continue</p>
          </div>

          <%!-- Flash Messages --%>
          <%= if Phoenix.Flash.get(@flash, :error) do %>
            <div class="alert alert-error text-sm mb-4 animate-shake">
              <.icon name="hero-exclamation-circle-mini" class="size-5" />
              <span>{Phoenix.Flash.get(@flash, :error)}</span>
            </div>
          <% end %>
          <%= if Phoenix.Flash.get(@flash, :info) do %>
            <div class="alert alert-success text-sm mb-4 animate-scale-in">
              <.icon name="hero-check-circle-mini" class="size-5" />
              <span>{Phoenix.Flash.get(@flash, :info)}</span>
            </div>
          <% end %>

          <form action="/auth/user/password/sign_in" method="post" class="space-y-5">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div>
              <label for="user_email" class="block text-sm font-semibold mb-2">Email</label>
              <label class="input input-bordered flex items-center gap-3 w-full">
                <.icon name="hero-envelope-mini" class="size-4 opacity-40" />
                <input
                  type="email"
                  name="user[email]"
                  id="user_email"
                  placeholder="you@example.com"
                  required
                  class="grow"
                  autocomplete="email"
                />
              </label>
            </div>

            <div>
              <label for="user_password" class="block text-sm font-semibold mb-2">Password</label>
              <label class="input input-bordered flex items-center gap-3 w-full">
                <.icon name="hero-lock-closed-mini" class="size-4 opacity-40" />
                <input
                  type="password"
                  name="user[password]"
                  id="user_password"
                  placeholder="Enter your password"
                  required
                  class="grow"
                  autocomplete="current-password"
                />
              </label>
            </div>

            <button type="submit" class="btn btn-gradient w-full gap-2 font-semibold text-base">
              <.icon name="hero-arrow-right-end-on-rectangle-mini" class="size-5" />
              Sign In
            </button>
          </form>

          <div class="relative my-6">
            <hr class="divider-gradient" />
            <span class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 px-3 bg-base-100 text-xs font-semibold tracking-widest text-base-content/40">
              NEW HERE?
            </span>
          </div>

          <div class="text-center">
            <a href="/register" class="btn btn-outline btn-primary w-full gap-2 font-semibold press-scale">
              <.icon name="hero-user-plus-mini" class="size-5" />
              Create an Account
            </a>
          </div>

          <p class="text-center mt-6 text-sm text-base-content/40">
            <a href="/" class="hover:text-primary transition-colors hover-icon-move">
              <.icon name="hero-arrow-left-mini" class="size-3.5 inline" /> Back to home
            </a>
          </p>
        </div>
      </div>
    </div>
    """
  end
end
