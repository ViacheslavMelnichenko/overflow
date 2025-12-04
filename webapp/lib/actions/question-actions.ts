'use server';

import {Question} from "@/lib/types";

export async function getQuestions(tag?: string): Promise<Question[]> {
    let url = 'http://overflow-api-staging.helios/questions';
    if (tag) url += `?tag=${tag}`;

    const response = await fetch(url);

    if (!response.ok) throw new Error('Failed to fetch questions');

    return response.json();
}