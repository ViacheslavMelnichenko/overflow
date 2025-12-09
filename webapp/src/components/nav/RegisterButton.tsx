import {Button} from "@heroui/button";
import {authConfig} from "@/lib/config";

export default function RegisterButton() {
    const issuer = process.env.AUTH_KEYCLOAK_ISSUER;
    const redirectUrl = process.env.AUTH_URL;
    
    const registerUrl = `${issuer}/protocol/openid-connect/registrations` +
        `?client_id=${authConfig.kcClientId}&redirect_uri=` +
        `${encodeURIComponent(redirectUrl!)}&response_type=code&scope=openid`;
    
    return (
        <Button as='a' href={registerUrl} color='secondary'>Register</Button>
    );
}