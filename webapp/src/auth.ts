import NextAuth from "next-auth"
import Keycloak from "next-auth/providers/keycloak"
import {authConfig} from "@/lib/config";

export const { handlers, signIn, signOut, auth } = NextAuth({
    trustHost: true,
    secret: authConfig.secret,
    debug: true,
    providers: [Keycloak({
        clientId: authConfig.kcClientId,
        clientSecret: authConfig.kcSecret,
        issuer: authConfig.kcIssuer,
        authorization: {
            params: {scope: 'openid profile email offline_access'},
            url: `${authConfig.kcIssuer}/protocol/openid-connect/auth`
        },
        token: {
            url: `${authConfig.kcInternal}/protocol/openid-connect/token`,
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            async request(context: any) {
                const params = new URLSearchParams({
                    grant_type: 'authorization_code',
                    client_id: context.provider.clientId,
                    client_secret: context.provider.clientSecret,
                    code: context.params.code,
                    redirect_uri: context.provider.callbackUrl,
                });

                console.log('[auth][token-request] URL:', context.provider.token.url);
                console.log('[auth][token-request] Params:', {
                    grant_type: 'authorization_code',
                    client_id: context.provider.clientId,
                    client_secret: '***',
                    code: context.params.code?.substring(0, 30) + '...',
                    redirect_uri: context.provider.callbackUrl,
                });

                const response = await fetch(context.provider.token.url, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded',
                    },
                    body: params,
                });

                const tokens = await response.json();

                console.log('[auth][token-response] Status:', response.status);
                console.log('[auth][token-response] Body:', {
                    ...tokens,
                    access_token: tokens.access_token ? tokens.access_token.substring(0, 30) + '...' : undefined,
                    refresh_token: tokens.refresh_token ? 'PRESENT' : 'MISSING',
                    id_token: tokens.id_token ? tokens.id_token.substring(0, 30) + '...' : undefined,
                });

                if (!response.ok) {
                    console.error('[auth][token-response] ERROR:', tokens);
                    throw new Error(`Token exchange failed: ${JSON.stringify(tokens)}`);
                }

                return { tokens };
            },
        },
        userinfo: `${authConfig.kcInternal}/protocol/openid-connect/userinfo`,
        checks: ['state'],
    })],
    callbacks: {
        async jwt({token, account, profile}) {
            const now = Math.floor(Date.now() / 1000);
            
            if (profile && profile.sub) {
                token.sub = profile.sub
            }
            
            if (account) {
                console.log('[auth][jwt] Account received:', {
                    provider: account.provider,
                    type: account.type,
                    hasAccessToken: !!account.access_token,
                    hasRefreshToken: !!account.refresh_token,
                    expiresIn: account.expires_in,
                    scope: account.scope,
                });
            }

            if (account && account.access_token && account.refresh_token) {
                token.accessToken = account.access_token
                token.refreshToken = account.refresh_token;
                token.accessTokenExpires = now + account.expires_in!;
                token.error = undefined;
                return token;
            }

            if (account && account.access_token && !account.refresh_token) {
                console.warn('[auth][jwt] No refresh token received - offline_access may not be configured');
                token.accessToken = account.access_token
                token.accessTokenExpires = now + account.expires_in!;
                return token;
            }

            if (token.accessTokenExpires && now < token.accessTokenExpires) {
                return token;
            }
            
            try {
                const response = await fetch(`${authConfig.kcInternal}/protocol/openid-connect/token`, {
                    method: 'POST',
                    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                    body: new URLSearchParams({
                        grant_type: 'refresh_token',
                        client_id: authConfig.kcClientId,
                        client_secret: authConfig.kcSecret,
                        refresh_token: token.refreshToken as string
                    })
                })

                const refreshed = await response.json()

                if (!response.ok) {
                    console.error('[auth] Failed to refresh token:', {
                        status: response.status,
                        error: refreshed
                    });
                    token.error = 'RefreshAccessTokenError';
                    return token;
                }

                token.accessToken = refreshed.access_token;
                token.refreshToken = refreshed.refresh_token;
                token.accessTokenExpires = now + refreshed.expires_in!;
            } catch (error) {
                console.error('[auth] Exception during token refresh:', error);
                token.error = 'RefreshAccessTokenError';
            }

            return token;
        },
        async session({session, token}) {
            if (token.sub) {
                session.user.id = token.sub
            }
            
            if (token.accessToken) {
                session.accessToken = token.accessToken;
            }
            
            if (token.accessTokenExpires) {
                session.expires = new Date(token.accessTokenExpires * 1000) as unknown as typeof session.expires;
            }
            return session;
        }
    }
})