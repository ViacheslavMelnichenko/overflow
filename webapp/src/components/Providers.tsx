'use client';

import {HeroUIProvider} from "@heroui/react";
import {ReactNode} from "react";
import {useRouter} from "next/navigation";

export default function Providers({children}: { children: ReactNode }) {
    const router = useRouter();

    return (
        <HeroUIProvider navigate={router.push} className='h-full flex flex-col'>
            {children}
        </HeroUIProvider>
    );
}