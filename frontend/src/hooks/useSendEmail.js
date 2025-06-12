
import { useState } from "react";
import axios from "axios";

const useSendEmail = (url) => {
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [success, setSuccess] = useState(false);

    const sendEmail = async (formData) => {
        console.log("formData:", formData);

        setLoading(true);
        setError(null);
        setSuccess(false);

        try {
            const response = await axios.post(url, formData);
            if (response.status === 200) {
                setSuccess(true);
            }
            return response; 
        } catch (err) {
            setError(err.response?.data?.detail || "Failed to send email");
            throw err;
        } finally {
            setLoading(false);
        }
    };

    return { sendEmail, loading, error, success };
};

export default useSendEmail;