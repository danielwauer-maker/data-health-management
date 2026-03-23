query 53140 "DH Customer Duplicate Email"
{
    QueryType = Normal;

    elements
    {
        dataitem(Customer; Customer)
        {
            column(Email; "E-Mail")
            {
            }

            column(CustomerCount)
            {
                Method = Count;
            }

            filter(EmailFilter; "E-Mail")
            {
            }
        }
    }
}